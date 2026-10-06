import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/ethereum/payment_uri.dart';
import '../../data/ethereum/tx_service.dart';
import '../../data/models/chain.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../state/controllers.dart';
import 'chain_selector.dart';

/// 转帐页：输入收款地址与金额 → 二次确认 → 广播交易。
///
/// 只支援原生代币（ETH / TRX），不含 ERC-20 / TRC-20。
///
/// 「目前在哪一条链上转帐」是这里最重要的资讯 —— 转错链等于丢钱，
/// 因此页面顶端是独立且醒目的网路卡，并可就地切换；收款地址也必须
/// 通过**目前这条链**的格式验证（扫码带来的链则会自动切过去）。
class SendPage extends ConsumerStatefulWidget {
  const SendPage({
    this.chain,
    this.initialAddress,
    super.key,
  });

  /// 进入时要套用的链（扫码进来时由 QR Code 决定）。
  ///
  /// `null` 表示沿用设定值。指定的话会同步写回设定，让转帐执行时
  /// 使用的链与画面上显示的链永远一致。
  final ChainType? chain;

  /// 预填的收款资料（扫码带入）。
  ///
  /// 可以是纯地址，也可以是完整的支付 URI
  /// （`ethereum:0x…?value=…` / `tron:T…?amount=…`）—— 后者连同金额与链
  /// 一起带入，让使用者扫完只要按确认。
  final String? initialAddress;

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  final TextEditingController _to = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  String? _addressError;
  String? _amountError;

  @override
  void initState() {
    super.initState();

    // 扫码带入的可能是纯地址，也可能是带金额与链的支付 URI。
    final initial = widget.initialAddress;
    final request = initial == null ? null : PaymentUri.fromScan(initial);
    if (initial != null) {
      if (request == null) {
        _to.text = initial.trim();
      } else {
        _to.text = request.address;
        final amount = request.amount;
        if (amount != null) _amount.text = _trimZeros(amount);
      }
    }

    // 目标链：优先采用扫码内容指定的链（地址格式已经限定它只能是那条链）。
    final target = request?.chain ?? widget.chain;
    if (target != null) {
      // 设定是唯一的真值来源（转帐时读的也是它），所以进入时就对齐，
      // 避免画面显示 A 链、实际送出 B 链。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(settingsProvider).chain != target) {
          ref.read(settingsProvider.notifier).setChain(target);
        }
      });
    }
  }

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _amountValue {
    final raw = _amount.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// 把错误代码映射成可读文案。
  String _errorText(String code) => switch (code) {
        'invalid-address' => context.s.walletErrInvalidAddress,
        'invalid-amount' => context.s.walletErrInvalidAmount,
        'insufficient-funds' => context.s.walletErrInsufficient,
        'no-rpc' => context.s.walletErrNoRpc,
        _ => context.s.walletErrNetwork,
      };

  /// 地址错误要能分辨「写错」与「别条链的地址」——后者的处理方式不同。
  String? _addressErrorFor(ChainType chain, String address) {
    if (TxService.isValidAddress(chain, address)) return null;
    final belongsElsewhere = ChainType.values
        .any((c) => c != chain && TxService.isValidAddress(c, address));
    return belongsElsewhere
        ? context.s.walletErrChainMismatch
        : context.s.walletErrInvalidAddress;
  }

  /// 验证并回传 (address, amount)；不合法时回传 null 并设好错误讯息。
  ({String address, double amount})? _validate(ChainType chain) {
    final s = context.s;
    final address = _to.text.trim();
    final amount = _amountValue;

    final addressOk =
        address.isNotEmpty && TxService.isValidAddress(chain, address);
    final amountOk = amount != null && amount > 0;

    setState(() {
      _addressError = address.isEmpty
          ? s.walletErrInvalidAddress
          : _addressErrorFor(chain, address);
      _amountError = amountOk ? null : s.walletErrInvalidAmount;
    });
    if (!addressOk || !amountOk) return null;
    return (address: address, amount: amount);
  }

  /// 切换转帐网路：改的是设定本身，因此余额与实际送出的链会一起跟上。
  Future<void> _switchChain(ChainType next) async {
    if (next == ref.read(settingsProvider).chain) return;
    await ref.read(settingsProvider.notifier).setChain(next);
    if (!mounted) return;
    // 已填的位址可能属于别条链，切换后立刻重新检视。
    final address = _to.text.trim();
    setState(() {
      _addressError =
          address.isEmpty ? null : _addressErrorFor(next, address);
    });
  }

  /// 开启扫码页（挑选地址模式），把结果填回表单。
  Future<void> _scan(ChainType chain) async {
    final raw = await context.push<String>('/scan?pick=1&chain=${chain.id}');
    if (raw == null || !mounted) return;
    await _applyScanned(raw, chain);
  }

  /// 套用扫码结果：地址必填，金额与链由 QR Code 决定（链不同就切过去）。
  Future<void> _applyScanned(String raw, ChainType current) async {
    final s = context.s;
    // 先以目前链解，失败再让它自己推断（例如在波场页扫到 0x 地址）。
    final request = PaymentUri.fromScan(raw, chain: current) ??
        PaymentUri.fromScan(raw);
    if (request == null) {
      showAppSnack(context, s.scanPickInvalid, danger: true);
      return;
    }

    if (request.chain != current) {
      await ref.read(settingsProvider.notifier).setChain(request.chain);
      if (!mounted) return;
      showAppSnack(
        context,
        s.walletSendNetworkNotice(ChainSelector.labelOf(s, request.chain)),
      );
    }

    setState(() {
      _to.text = request.address;
      _addressError = null;
      final amount = request.amount;
      if (amount != null) {
        _amount.text = _trimZeros(amount);
        _amountError = null;
      }
    });
  }

  /// 金额填回输入框时去掉多余的尾数零（1.500000 → 1.5）。
  static String _trimZeros(double value) {
    final text = value.toStringAsFixed(6);
    if (!text.contains('.')) return text;
    return text
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _confirmAndSend(ChainType chain) async {
    final parsed = _validate(chain);
    if (parsed == null) return;

    final s = context.s;
    final config = ChainConfig.of(chain);
    final chainLabel = ChainSelector.labelOf(s, chain);

    // RPC 端点与所选链不符（例如把 Base 的 RPC 贴到以太坊）时硬性阻断：
    // 这种情况下余额查得到、交易也送得出去，只是会送到错的网路上。
    // 因此不能只靠画面上的红字警告，这里直接不给送。
    // chainId 尚未查到（离线）时无法判定，维持放行以免误伤。
    final chainId = ref.read(walletInfoProvider).value?.chainId;
    if (config.isWrongChain(chainId)) {
      _showSnack(s.walletRpcMismatch, danger: true);
      return;
    }

    // 二次确认：链上交易不可撤回，先让使用者核对网路、地址与金额。
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.walletSendConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ConfirmRow(
                  label: s.walletSendNetwork,
                  // 全名 + 代号一起核对，避免把 CNT 看成 ETH 之类的误会。
                  value: '$chainLabel · ${config.name} (${config.symbol})',
                ),
                const SizedBox(height: 12),
                _ConfirmRow(label: s.walletSendTo, value: parsed.address),
                const SizedBox(height: 12),
                _ConfirmRow(
                  label: s.walletAmount,
                  value:
                      '${Formatters.amount(parsed.amount, config.displayDecimals)} ${config.symbol}',
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.walletSendConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final result = await ref
        .read(walletSendProvider.notifier)
        .send(toAddress: parsed.address, amount: parsed.amount);
    if (!mounted) return;

    if (result == null) {
      final code = ref.read(walletSendProvider).error ?? 'network';
      _showSnack(_errorText(code), danger: true);
      return;
    }
    _showSuccess(result);
  }

  void _showSnack(String message, {bool danger = false}) {
    showAppSnack(context, message, danger: danger);
  }

  void _showSuccess(TxResult result) {
    final s = context.s;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            Text(s.walletSendSuccess),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.walletTxHash,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              result.hash,
              style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
            ),
            if (result.explorerUrl != null) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(result.explorerUrl!);
                  if (uri == null) return;
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(s.walletViewTx),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 从扫码页进来时返回堆叠可能只有这一页，pop 不掉就回钱包。
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/wallet');
              }
            },
            child: Text(s.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final send = ref.watch(walletSendProvider);
    final info = ref.watch(walletInfoProvider);

    // 唯一的真值来源：设定里的链。画面、余额与实际送出的链都读它。
    final chain = settings.chain;
    final config = ChainConfig.of(chain);
    final balance = info.value?.balanceNative;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.walletSendTitle),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: <Widget>[
              // -------------------------------------------- 目前转帐网路
              _NetworkCard(
                chain: chain,
                config: config,
                chainId: info.value?.chainId,
                rpcUrl: settings.rpcFor(chain),
                onChanged: _switchChain,
              ),
              const SizedBox(height: 20),
              // ------------------------------------------------ 收款地址
              TextField(
                controller: _to,
                autocorrect: false,
                enableSuggestions: false,
                minLines: 1,
                maxLines: 2,
                onChanged: (_) {
                  if (_addressError != null) {
                    setState(() => _addressError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: s.walletSendTo,
                  hintText: s.walletSendToHint,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  errorText: _addressError,
                  suffixIcon: IconButton(
                    tooltip: s.walletScanAddress,
                    onPressed: () => _scan(chain),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ---------------------------------------------------- 金额
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) {
                  if (_amountError != null) setState(() => _amountError = null);
                },
                decoration: InputDecoration(
                  labelText: s.walletAmount,
                  hintText: s.walletAmountHint,
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: config.symbol,
                  errorText: _amountError,
                  helperText: balance == null
                      ? null
                      : '${s.walletAvailable}: '
                          '${Formatters.amount(balance, config.displayDecimals)} '
                          '${config.symbol}',
                  helperStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (balance != null && balance > 0) ...<Widget>[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      // 保留一点手续费空间，避免「全部」之后必然失败。
                      final usable = chain == ChainType.tron
                          ? balance - 1
                          : balance * 0.98;
                      if (usable <= 0) return;
                      _amount.text = usable.toStringAsFixed(
                        config.displayDecimals,
                      );
                      setState(() => _amountError = null);
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 17),
                    label: Text(s.walletUseMax),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: send.busy ? null : () => _confirmAndSend(chain),
                  icon: send.busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 19),
                  label: Text(send.busy ? s.walletSending : s.walletSendConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 转帐页顶端的「目前转帐网路」卡。
///
/// 独立成一块、放在所有输入之前：转帐前第一件要看清楚的事就是「现在
/// 在哪条链上」。右侧的切换器与钱包页共用设定，切了就整页一起更新。
class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.chain,
    required this.config,
    required this.chainId,
    required this.rpcUrl,
    required this.onChanged,
  });

  final ChainType chain;
  final ChainConfig config;
  final int? chainId;
  final String rpcUrl;
  final ValueChanged<ChainType> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final label = ChainSelector.labelOf(s, chain);
    // 有 chainId 就显示 chainId（最能代表「哪一条链」），否则退回端点。
    final detail = chainId != null ? 'chainId $chainId' : rpcUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ChainSelector.iconOf(chain), size: 19, color: AppColors.brand),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  s.walletSendNetwork,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.brand,
                  ),
                ),
              ),
              ChainSelector(
                chain: chain,
                onChanged: onChanged,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  config.symbol,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              height: 1.4,
              color: config.isWrongChain(chainId)
                  ? AppColors.danger
                  : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          // 端点填错时（例如把 Base 的 RPC 贴到以太坊），chainId 会对不上：
          // 余额查得到、交易也送得出去，只是送到错的网路上 —— 必须挡在这里。
          if (config.isWrongChain(chainId)) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.walletRpcMismatch,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.walletSendNetworkNotice('$label (${config.symbol})'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 确认对话框中的一列「标签 / 值」。
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
