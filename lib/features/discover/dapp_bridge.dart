import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/hex.dart';
import '../../data/models/chain.dart';
import '../../state/controllers.dart';

/// JS 通道名称：注入后页面侧用 `window.NexusDapp.postMessage(...)` 把请求传给 Flutter。
const String kDappChannel = 'NexusDapp';

/// 注入到 WebView 的 EIP-1193 provider（window.ethereum）。
///
/// 它把每个 `request({method, params})` 以 JSON 形式通过 [kDappChannel] 抛给
/// Flutter，Flutter 处理完再呼叫 `window.ethereum._resolve(id, json)` /
/// `_reject(id, json)` 把结果回传。其余只读 JSON-RPC 方法（eth_call /
/// eth_getBalance / eth_gasPrice …）由 Flutter 直接转发到当前链的 RPC。
const String kDappProviderJs = r'''
(function () {
  var CHANNEL = 'NexusDapp';
  var seq = 0;
  var pending = {};
  function resolve(id, resultJson) {
    var p = pending[id];
    if (p) { pending[id] = null; p.resolve(JSON.parse(resultJson)); }
  }
  function reject(id, errorJson) {
    var p = pending[id];
    if (p) { pending[id] = null; p.reject(new Error(JSON.parse(errorJson))); }
  }
  function post(method, params) {
    return new Promise(function (res, rej) {
      if (!window[CHANNEL]) { rej(new Error('provider not ready')); return; }
      var id = (++seq);
      pending[id] = { resolve: res, reject: rej };
      try {
        window[CHANNEL].postMessage(JSON.stringify({ id: id, method: method, params: params || [] }));
      } catch (e) { rej(e); }
    });
  }
  var listeners = {};
  function emit(name, data) {
    (listeners[name] || []).forEach(function (h) { try { h(data); } catch (e) {} });
  }
  var provider = {
    isNexus: true,
    isMetaMask: false,
    request: function (args) { return post(args.method, args.params); },
    sendAsync: function (payload, cb) {
      post(payload.method, payload.params)
        .then(function (r) { cb(null, { jsonrpc: '2.0', id: payload.id, result: r }); },
              function (err) { cb(err, null); });
    },
    send: function (method, params) {
      if (typeof method === 'object' && method !== null && method.method) {
        return post(method.method, method.params);
      }
      return post(method, params);
    },
    enable: function () { return post('eth_requestAccounts', []); },
    on: function (event, handler) {
      (listeners[event] = listeners[event] || []).push(handler);
      return this;
    },
    removeListener: function (event, handler) {
      if (listeners[event]) {
        listeners[event] = listeners[event].filter(function (h) { return h !== handler; });
      }
    },
    _resolve: resolve,
    _reject: reject,
    _emit: emit
  };
  window.ethereum = provider;
})();
''';

/// DApp 请求被用户拒绝或参数非法时抛出。
class DappError implements Exception {
  const DappError(this.message, [this.code]);

  final String message;
  final int? code;

  @override
  String toString() => message;
}

/// 一条来自页面的 JSON-RPC 请求。
class DappRequest {
  DappRequest({
    required this.id,
    required this.method,
    required this.params,
    this.origin,
  });

  final dynamic id;
  final String method;
  final List<dynamic> params;
  final String? origin;
}

/// 把 App 钱包桥接成 EIP-1193 provider：处理账户 / 签名 / 发交易 / 切链，
/// 其余只读 JSON-RPC 直接转发到当前链的节点。
class DappWalletBridge {
  DappWalletBridge({
    required this.ref,
    required this.context,
    required this.controller,
  });

  final WidgetRef ref;
  final BuildContext context;
  final WebViewController controller;

  bool _connected = false;

  // ----------------------------------------------------------------- 入口

  Future<void> handleRaw(String message) async {
    late Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = msg['id'];
    final method = (msg['method'] as String?) ?? '';
    final params =
        (msg['params'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    final origin = msg['origin'] as String?;
    try {
      final result = await _dispatch(
        DappRequest(
          id: id,
          method: method,
          params: params,
          origin: origin,
        ),
      );
      await _resolve(id, result);
    } on DappError catch (e) {
      await _reject(id, e.message);
    } catch (e) {
      await _reject(id, '$e');
    }
  }

  Future<dynamic> _dispatch(DappRequest req) {
    switch (req.method) {
      case 'eth_requestAccounts':
        return _requestAccounts(req);
      case 'eth_accounts':
        return Future<dynamic>.value(_accounts());
      case 'personal_sign':
      case 'eth_sign':
        return _personalSign(req, legacy: req.method == 'eth_sign');
      case 'eth_signTypedData':
      case 'eth_signTypedData_v4':
        return _signTypedData(req);
      case 'eth_sendTransaction':
        return _sendTransaction(req);
      case 'wallet_switchEthereumChain':
        return _switchChain(req);
      case 'wallet_addEthereumChain':
        return _addChain(req);
      default:
        // 其余（eth_call / eth_getBalance / eth_gasPrice / eth_chainId …）透明转发。
        return _relay(req.method, req.params);
    }
  }

  // ----------------------------------------------------------------- 本地方法

  List<String> _accounts() =>
      _connected ? <String>[_address()] : const <String>[];

  Future<List<String>> _requestAccounts(DappRequest req) async {
    final address = _address();
    final approved = await _approve(
      title: context.s.dappConnect,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);
    _connected = true;
    await _emit('connect', <String, dynamic>{
      'chainId': await _chainIdHex(),
    });
    await _emit('accountsChanged', <String>[_address()]);
    return <String>[address];
  }

  Future<String> _personalSign(DappRequest req, {required bool legacy}) async {
    final address = _address();
    final decoded = _decodeSignMessage(req.params);
    final approved = await _approve(
      title: context.s.dappSign,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
        (context.s.dappMessage, decoded.text),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);
    final privateHex = _privateHex();
    final bytes = decoded.bytes;
    final signature = legacy
        ? EthSigUtil.signMessage(privateKey: privateHex, message: bytes)
        : EthSigUtil.signPersonalMessage(
            privateKey: privateHex, message: bytes);
    return signature;
  }

  Future<String> _signTypedData(DappRequest req) async {
    final address = _address();
    final parsed = _parseTypedDataParams(req.params);
    final approved = await _approve(
      title: context.s.dappSign,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
        (context.s.dappMessage, parsed.summary),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);
    final privateHex = _privateHex();
    return EthSigUtil.signTypedData(
      privateKey: privateHex,
      jsonData: parsed.json,
      version: TypedDataVersion.V4,
    );
  }

  Future<String> _sendTransaction(DappRequest req) async {
    final address = _address();
    final tx = (req.params.first as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final from = (tx['from'] as String?) ?? '';
    if (from.isNotEmpty && from.toLowerCase() != address.toLowerCase()) {
      throw const DappError('from address mismatch', 4100);
    }
    final approved = await _approve(
      title: context.s.dappTransaction,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
        if (tx['to'] != null)
          (context.s.dappTo, _short(tx['to'] as String)),
        (context.s.dappNetwork, _networkName()),
        if (tx['value'] != null && tx['value'] != '0x0')
          (context.s.dappAmount, _weiToEther(tx['value'] as String)),
        if ((tx['data'] as String?) != null && (tx['data'] as String) != '0x')
          (context.s.dappMessage, '0x… (${(tx['data'] as String).length - 2} bytes)'),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);
    return _broadcast(tx);
  }

  Future<dynamic> _switchChain(DappRequest req) async {
    final param =
        (req.params.first as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final chainId = _hexInt(param['chainId'] as String? ?? '0x0');
    final type = _chainTypeById(chainId);
    if (type == null) {
      throw const DappError('Unrecognized chain ID', 4902);
    }
    await ref.read(settingsProvider.notifier).setChain(type);
    final hex = '0x${chainId.toRadixString(16)}';
    await _emit('chainChanged', hex);
    return null;
  }

  Future<dynamic> _addChain(DappRequest req) async {
    // MVP：仅支持切换到已内置的链；自定义 RPC 的「新增链」暂以未识别处理。
    final param =
        (req.params.first as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final chainId = _hexInt(param['chainId'] as String? ?? '0x0');
    final type = _chainTypeById(chainId);
    if (type == null) {
      throw const DappError('Unrecognized chain ID', 4902);
    }
    await ref.read(settingsProvider.notifier).setChain(type);
    final hex = '0x${chainId.toRadixString(16)}';
    await _emit('chainChanged', hex);
    return null;
  }

  // ----------------------------------------------------------------- 广播交易

  Future<String> _broadcast(Map<String, dynamic> tx) async {
    final chain = _chain();
    final rpcUrl = ref.read(settingsProvider).rpcFor(chain);
    if (rpcUrl.trim().isEmpty) {
      throw const DappError('No RPC endpoint configured', 4900);
    }
    final client = Web3Client(rpcUrl, http.Client());
    try {
      final credentials = EthPrivateKey(Hex.decode(_privateHex()));
      final chainId =
          ChainConfig.of(chain).expectedChainId ??
          (await client.getChainId()).toInt();

      final nonceHex = tx['nonce'] as String?;
      final nonce = nonceHex != null
          ? _hexInt(nonceHex)
          : await client.getTransactionCount(
              credentials.address,
              atBlock: BlockNum.pending(),
            );

      final gasPriceHex = tx['gasPrice'] as String?;
      final maxFeeHex = tx['maxFeePerGas'] as String?;
      final maxPriorityHex = tx['maxPriorityFeePerGas'] as String?;
      final gasHex = tx['gas'] as String?;

      EtherAmount? gasPrice = gasPriceHex != null
          ? EtherAmount.fromBigInt(EtherUnit.wei, _hexBigInt(gasPriceHex))
          : null;
      EtherAmount? maxFee = maxFeeHex != null
          ? EtherAmount.fromBigInt(EtherUnit.wei, _hexBigInt(maxFeeHex))
          : null;
      EtherAmount? maxPriority = maxPriorityHex != null
          ? EtherAmount.fromBigInt(EtherUnit.wei, _hexBigInt(maxPriorityHex))
          : null;

      // 旧式交易：既没给 gasPrice 也没给 EIP-1559 费用时，向节点询问 gasPrice。
      if (maxFee == null && gasPrice == null) {
        gasPrice = await client.getGasPrice();
      }
      // EIP-1559 但缺 maxPriorityFeePerGas：默认取 maxFee 的四分之一。
      if (maxFee != null && maxPriority == null) {
        final quarter = maxFee.getInWei ~/ BigInt.from(4);
        maxPriority = EtherAmount.fromBigInt(
            EtherUnit.wei,
            quarter > BigInt.zero ? quarter : maxFee.getInWei);
      }

      final transaction = Transaction(
        to: tx['to'] != null ? EthereumAddress.fromHex(tx['to'] as String) : null,
        value: tx['value'] != null
            ? EtherAmount.fromBigInt(
                EtherUnit.wei, _hexBigInt(tx['value'] as String))
            : EtherAmount.zero(),
        data: tx['data'] != null && tx['data'] != '0x'
            ? Hex.decode(tx['data'] as String)
            : Uint8List(0),
        nonce: nonce,
        gasPrice: gasPrice,
        maxFeePerGas: maxFee,
        maxPriorityFeePerGas: maxPriority,
        // maxGas 为 null 时，web3dart 会自动向节点估算 gas 上限。
        maxGas: gasHex != null ? _hexInt(gasHex) : null,
      );

      return await client.sendTransaction(
        credentials,
        transaction,
        chainId: chainId,
      );
    } finally {
      client.dispose();
    }
  }

  // ----------------------------------------------------------------- 节点中继

  Future<dynamic> _relay(String method, List<dynamic> params) async {
    final chain = _chain();
    final rpcUrl = ref.read(settingsProvider).rpcFor(chain);
    if (rpcUrl.trim().isEmpty) {
      throw const DappError('No RPC endpoint configured', 4900);
    }
    final response = await http
        .post(
          Uri.parse(rpcUrl),
          headers: <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw DappError('RPC error (${response.statusCode})', -32000);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final error = body['error'];
    if (error != null) {
      throw DappError(
        error['message']?.toString() ?? 'RPC error', error['code'] as int?);
    }
    return body['result'];
  }

  // ----------------------------------------------------------------- 回传页面

  Future<void> _resolve(dynamic id, dynamic result) async {
    final data = jsonEncode(result);
    await controller
        .runJavaScript('window.ethereum._resolve($id, $data)')
        .catchError((_) {});
  }

  Future<void> _reject(dynamic id, String message) async {
    final data = jsonEncode(message);
    await controller
        .runJavaScript('window.ethereum._reject($id, $data)')
        .catchError((_) {});
  }

  Future<void> _emit(String name, dynamic data) async {
    final dataJson = jsonEncode(data);
    await controller
        .runJavaScript(
            'window.ethereum._emit(${jsonEncode(name)}, $dataJson)')
        .catchError((_) {});
  }

  // ----------------------------------------------------------------- 授权弹窗

  Future<bool> _approve({
    required String title,
    required String? origin,
    required List<(String, String)> rows,
  }) async {
    if (!context.mounted) return false;
    final host = _hostOf(origin);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ApprovalSheet(
        title: title,
        host: host,
        rows: rows,
      ),
    );
    return result == true;
  }

  // ----------------------------------------------------------------- 工具

  String _address() {
    final identity = ref.read(coreProvider).identity;
    if (identity == null) throw const DappError('No account', 4100);
    return identity.address;
  }

  String _privateHex() {
    final identity = ref.read(coreProvider).identity;
    if (identity == null) throw const DappError('No account', 4100);
    return identity.ethPrivateHex;
  }

  ChainType _chain() => ref.read(settingsProvider).chain;

  String _networkName() {
    final chain = _chain();
    switch (chain) {
      case ChainType.ethereum:
        return 'Ethereum';
      case ChainType.base:
        return 'Base';
      case ChainType.arbitrum:
        return 'Arbitrum';
      case ChainType.bsc:
        return 'BNB Chain';
      case ChainType.tron:
        return 'TRON';
      case ChainType.besu:
        return 'WEB6';
    }
  }

  Future<String> _chainIdHex() async {
    final chain = _chain();
    final expected = ChainConfig.of(chain).expectedChainId;
    if (expected != null) return '0x${expected.toRadixString(16)}';
    final nodeId = await _relay('eth_chainId', const <dynamic>[]);
    return nodeId is String ? nodeId : '0x${_hexInt('$nodeId').toRadixString(16)}';
  }

  ChainType? _chainTypeById(int id) {
    for (final type in ChainType.values) {
      if (ChainConfig.of(type).expectedChainId == id) return type;
    }
    return null;
  }

  static ({Uint8List bytes, String text}) _decodeSignMessage(
      List<dynamic> params) {
    // personal_sign 常见两种参数顺序：[data, address] 或 [address, data]；
    // 取「非地址」的那一项作为消息内容。
    final candidates = params.whereType<String>().toList();
    final nonAddress = candidates
        .where((p) => !(p.startsWith('0x') && p.length == 42))
        .toList();
    final message = nonAddress.isNotEmpty
        ? nonAddress.first
        : (candidates.isNotEmpty ? candidates.first : '');
    final trimmed = message.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      try {
        final bytes = Hex.decode(trimmed);
        return (bytes: bytes, text: utf8.decode(bytes, allowMalformed: true));
      } catch (_) {
        return (bytes: utf8.encode(trimmed), text: trimmed);
      }
    }
    return (bytes: utf8.encode(trimmed), text: trimmed);
  }

  static ({String json, String summary}) _parseTypedDataParams(
      List<dynamic> params) {
    // eth_signTypedData_v4 参数顺序：[address, json] 或 [json, address]。
    final candidates = params.whereType<String>().toList();
    final objects = candidates.where((p) => p.trim().startsWith('{')).toList();
    final json = objects.isNotEmpty
        ? objects.first
        : (candidates.isNotEmpty ? candidates.first : '{}');
    String summary;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final domain = map['domain'] as Map?;
      final primary = map['primaryType'] as String? ?? '';
      final name = (domain?['name'] as String?) ?? '';
      summary = name.isNotEmpty ? '$name · $primary' : primary;
      if (summary.isEmpty) summary = 'EIP-712';
    } catch (_) {
      summary = 'EIP-712';
    }
    return (json: json, summary: summary);
  }

  static BigInt _hexBigInt(String hex) =>
      BigInt.parse(hex.replaceFirst('0x', '').replaceFirst('0X', ''),
          radix: 16);

  static int _hexInt(String hex) => _hexBigInt(hex).toInt();

  static String _weiToEther(String hex) {
    final v = _hexBigInt(hex);
    final whole = v ~/ BigInt.from(10).pow(18);
    final fraction = (v % BigInt.from(10).pow(18))
        .toString()
        .padLeft(18, '0')
        .replaceAll(RegExp(r'0+$'), '');
    return fraction.isEmpty
        ? whole.toString()
        : '$whole.$fraction';
  }

  static String _hostOf(String? url) {
    if (url == null) return '';
    final uri = Uri.tryParse(url);
    return uri?.host ?? url;
  }

  static String _short(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}

/// 钱包操作授权弹窗：展示请求来源与摘要，确认 / 取消。
class _ApprovalSheet extends StatelessWidget {
  const _ApprovalSheet({
    required this.title,
    required this.host,
    required this.rows,
  });

  final String title;
  final String host;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (host.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                s.dappSite.isNotEmpty ? '${s.dappSite}: $host' : host,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 84,
                        child: Text(
                          r.$1,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          r.$2,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(s.confirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
