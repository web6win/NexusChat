import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' show hexToBytes, keccak256, sign;
import 'package:web3dart/web3dart.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/hex.dart';
import '../../shared/feedback.dart';
import '../../data/ethereum/tx_service.dart';
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

/// 波场（TRON）provider：`window.tronWeb` / `window.tronLink`（TronLink 相容）。
///
/// 做法与 EVM 不同：TRON DApp（JustLend / SunSwap 等）大量依赖真正的
/// `tronWeb` 能力与 ABI 编解码，手写模仿几乎不可能相容。因此这里：
/// 1. 使用**真正的 tronWeb 函式库**（页面自带的、或从 CDN 载入）建立实例，
///    节点通讯、交易建构、合约读取全部由它自己处理（纯 HTTP，不需私钥）；
/// 2. 只把「签章」与「连线授权」接到 App 钱包 —— 私钥永远不进页面 JS。
const String _tronTemplate = r'''
(function () {
  var CHANNEL = 'NexusDapp';
  var ADDRESS = '__TRON_ADDRESS__';
  var ADDRESS_HEX = '__TRON_ADDRESS_HEX__';
  var HOST = '__TRON_HOST__';
  // 没设定节点时会让建构式直接抛错，退回官方节点。
  if (!HOST) HOST = 'https://api.trongrid.io';
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

  var lastError = '';

  /// 建立 tronWeb 实例，并处理两种常见的打包/版本差异。
  function newTronWeb() {
    var Ctor = window.TronWeb;
    // 1) 部分 UMD 打包会把实体放在 .default 底下。
    if (Ctor && typeof Ctor !== 'function' && typeof Ctor.default === 'function') {
      Ctor = Ctor.default;
    }
    if (typeof Ctor !== 'function') {
      lastError = 'TronWeb not a constructor (type=' + (typeof window.TronWeb) + ')';
      return null;
    }
    // 2) 不同版本接受的节点参数不同：fullHost 或三个节点分别给。
    try {
      return new Ctor({ fullHost: HOST });
    } catch (e) {
      lastError = 'ctor(fullHost): ' + (e && e.message ? e.message : String(e));
    }
    try {
      return new Ctor({
        fullNode: HOST, solidityNode: HOST, eventServer: HOST
      });
    } catch (e) {
      lastError += ' | ctor(3-node): ' + (e && e.message ? e.message : String(e));
    }
    return null;
  }

  function installTron() {
    if (!window.TronWeb) {
      lastError = 'no window.TronWeb';
      return false;
    }
    var tw = newTronWeb();
    if (!tw) return false;
    // setAddress() 各版本接受的格式不一（有的要 hex 41…，有的接受 base58），
    // 因此除了尝试呼叫，最后一定直接写入 defaultAddress，避免它是空的 ——
    // DApp 等不到地址就会一直转圈。
    if (ADDRESS_HEX && typeof tw.setAddress === 'function') {
      try { tw.setAddress(ADDRESS_HEX); } catch (e) {}
    }
    tw.defaultAddress = { base58: ADDRESS, hex: ADDRESS_HEX, name: '' };
    tw.defaultPrivateKey = '';
    tw.ready = true;
    tw.isNexus = true;
    // 签章与讯息签章改由 App 钱包处理，私钥不进页面。
    try {
      tw.trx.sign = function (transaction) {
        return post('tron_signTransaction', [transaction]).then(function (signature) {
          if (transaction && typeof transaction === 'object') {
            transaction.signature = transaction.signature || [];
            transaction.signature.push(signature);
          }
          return transaction;
        });
      };
      tw.trx.signMessageV2 = function (message) {
        return post('tron_signMessage', [message]);
      };
      if (typeof tw.trx.signMessage !== 'function') {
        tw.trx.signMessage = tw.trx.signMessageV2;
      }
    } catch (e) {}
    window.tronWeb = tw;
    // 部分 DApp 读的是 tronLink.tronWeb，一并指过去。
    if (window.tronLink) window.tronLink.tronWeb = tw;
    diag('installed');
    return true;
  }

  /// 回报安装状态给 Flutter，方便判断「一直转圈」到底卡在哪一步。
  function diag(note) {
    try {
      var addr = '';
      if (window.tronWeb && window.tronWeb.defaultAddress) {
        addr = window.tronWeb.defaultAddress.base58 || '';
      }
      post('_tronDiag', [{
        note: note,
        lib: !!window.TronWeb,
        tronWeb: !!window.tronWeb,
        addr: addr,
        host: HOST,
        err: lastError
      }]);
    } catch (e) {}
  }

  window.__nexusInstallTron = installTron;

  window.tronLink = {
    ready: true,
    isNexus: true,
    tronWeb: null,
    request: function (payload) {
      var method = payload && payload.method;
      if (method === 'tron_requestAccounts') return post('tron_requestAccounts', []);
      return Promise.reject(new Error('unsupported method: ' + method));
    }
  };

  // tronWeb 可能尚未载入：先试一次，失败就注入 script 等 onload 再装。
  if (!installTron()) {
    diag('install-failed-wait-cdn');
    try {
      var s = document.createElement('script');
      s.src = window.__nexusTronLibUrl ||
        'https://cdn.jsdelivr.net/npm/tronweb/dist/TronWeb.js';
      s.onload = function () {
        try { if (installTron()) return; } catch (e) {}
        diag('cdn-loaded-but-install-failed');
      };
      s.onerror = function () { diag('cdn-script-error'); };
      (document.head || document.documentElement).appendChild(s);
    } catch (e) {
      diag('cdn-inject-error');
    }
  }
})();
''';

/// 产生波场 provider 的注入脚本。
///
/// [address] 为钱包波场地址（Base58，T 开头）；[host] 为波场节点 API 根网址。
String tronProviderJs({
  required String address,
  required String addressHex,
  required String host,
}) =>
    _tronTemplate
        .replaceAll('__TRON_ADDRESS__', address)
        .replaceAll('__TRON_ADDRESS_HEX__', addressHex)
        .replaceAll('__TRON_HOST__', host);

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
      case 'tron_requestAccounts':
        return _tronRequestAccounts(req);
      case 'tron_signTransaction':
        return _tronSignTransaction(req);
      case 'tron_signMessage':
        return _tronSignMessage(req);
      case '_tronDiag':
        return _tronDiag(req);
      default:
        // 其余（eth_call / eth_getBalance / eth_gasPrice / eth_chainId …）透明转发。
        return _relay(req.method, req.params);
    }
  }

  // ----------------------------------------------------------------- 本地方法

  List<String> _accounts() =>
      _connected ? <String>[_address()] : const <String>[];

  /// 目前是否已授权给这个网站（eth_requestAccounts 通过后为 true）。
  bool get connected => _connected;

  /// 断开与本网站钱包的连线：之后 eth_accounts 会回传空阵列，
  /// 网站必须重新请求授权才能拿到地址。
  void disconnect() {
    if (!_connected) return;
    _connected = false;
    unawaited(_emit('accountsChanged', const <String>[]));
  }

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

  // ----------------------------------------------------------------- 波场

  String _tronAddress() {
    final identity = ref.read(coreProvider).identity;
    final tron = identity?.tronAddress ?? '';
    if (tron.isEmpty) throw const DappError('No TRON account', 4100);
    return tron;
  }

  /// 波场专用私钥（195' 路径）—— 波场签章一律用它。
  Uint8List _tronPrivateKeyBytes() =>
      hexToBytes(_tronPrivateHex().replaceFirst(RegExp(r'^0[xX]'), ''));

  String _tronPrivateHex() {
    final identity = ref.read(coreProvider).identity;
    if (identity == null) throw const DappError('No account', 4100);
    return identity.tronPrivateHex;
  }

  /// 波场连线授权（对应 TronLink 的 `tron_requestAccounts`）。
  Future<Map<String, dynamic>> _tronRequestAccounts(DappRequest req) async {
    final address = _tronAddress();
    final approved = await _approve(
      title: context.s.dappConnect,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
        (context.s.dappNetwork, 'TRON'),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);
    _connected = true;
    return <String, dynamic>{
      'code': 200,
      'data': <String, dynamic>{'address': address, 'name': ''},
    };
  }

  /// 波场交易签章。
  ///
  /// 与以太坊不同：TRON 是对 **txID = sha256(raw_data)** 直接做 secp256k1
  /// ECDSA（不能再过一次 keccak256），签章格式也用 [TxService.packSignature]
  /// 转成 java-tron 要求的样子（v 为 0/1 且 low-S），否则节点会拒收。
  Future<String> _tronSignTransaction(DappRequest req) async {
    final tx = (req.params.first as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final rawHex = tx['raw_data_hex'] as String?;
    if (rawHex == null || rawHex.isEmpty) {
      throw const DappError('missing raw_data_hex', -32602);
    }
    final address = _tronAddress();
    final rows = <(String, String)>[
      (context.s.dappAccount, _short(address)),
      (context.s.dappNetwork, 'TRON'),
    ];
    final type = _tronContractType(tx);
    if (type.isNotEmpty) rows.add((context.s.dappMessage, type));

    final approved = await _approve(
      title: context.s.dappTransaction,
      origin: req.origin,
      rows: rows,
    );
    if (!approved) throw const DappError('User rejected the request', 4001);

    final txId = Uint8List.fromList(sha256.convert(hexToBytes(rawHex)).bytes);
    // 用波场专用钥匙签章，才能对应 tronWeb.defaultAddress 的那个地址。
    final signature = sign(txId, _tronPrivateKeyBytes());
    return TxService.packSignature(signature);
  }

  /// 波场讯息签章（对应 tronWeb 的 `signMessageV2`）：
  /// `keccak256("\x19TRON Signed Message:\n32" + keccak256(message))`。
  ///
  /// ⚠️ 各版本 tronWeb 的讯息签章语意略有差异，此实作**尚未经 JustLend /
  /// SunSwap 实测**；若对方验签失败请把错误回报，再依实际语意校正。
  Future<String> _tronSignMessage(DappRequest req) async {
    final address = _tronAddress();
    final message = req.params.isEmpty ? '' : '${req.params.first}';
    final approved = await _approve(
      title: context.s.dappSign,
      origin: req.origin,
      rows: <(String, String)>[
        (context.s.dappAccount, _short(address)),
        (context.s.dappMessage, message),
      ],
    );
    if (!approved) throw const DappError('User rejected the request', 4001);

    final inner = keccak256(utf8.encode(message));
    final header = utf8.encode('\u0019TRON Signed Message:\n32');
    final digest = keccak256(Uint8List.fromList(<int>[...header, ...inner]));
    final signature = sign(digest, _tronPrivateKeyBytes());
    return '${_padHex(signature.r)}${_padHex(signature.s)}'
        '${signature.v.toRadixString(16).padLeft(2, '0')}';
  }

  /// 波场注入层的安装状态回报（除错用）：把状态印出来并显示提示，
  /// 方便判断 DApp「一直转圈」卡在哪一步。
  Future<dynamic> _tronDiag(DappRequest req) async {
    final info = (req.params.first as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final msg = 'tron diag: note=${info['note']} lib=${info['lib']} '
        'tronWeb=${info['tronWeb']} addr=${info['addr']} '
        'host=${info['host']} err=${info['err']}';
    debugPrint(msg);
    if (context.mounted) showAppSnack(context, msg);
    return null;
  }

  static String _padHex(BigInt value) => value.toRadixString(16).padLeft(64, '0');

  static String _tronContractType(Map<String, dynamic> tx) {
    final raw = tx['raw_data'] as Map?;
    final contracts = raw?['contract'];
    if (contracts is List && contracts.isNotEmpty) {
      final first = contracts.first;
      if (first is Map) return (first['type'] as String?) ?? '';
    }
    return '';
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
