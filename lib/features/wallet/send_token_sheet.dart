import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/auth.dart';
import '../../data/ethereum/tx_service.dart';
import '../../data/models/chain.dart';
import '../../data/models/token_def.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';
import 'chain_selector.dart';
import 'token_panel.dart';

/// 点击 ERC-20 通证后弹出的转帐表单：填收款地址与金额 → 二次确认 → 广播
/// `transfer` 合约呼叫。仅支援 EVM 系（以太坊 / Base / Arbitrum / BSC / Besu），
/// TRON 上的 TRC-20 会被挡下并提示「暂不支援」。
class SendTokenSheet extends ConsumerStatefulWidget {
  const SendTokenSheet({required this.chain, required this.token, super.key});

  final ChainType chain;
  final TokenDef token;

  /// 以底部面板形式弹出。
  static void show(
    BuildContext context,
    ChainType chain,
    TokenDef token,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => SendTokenSheet(chain: chain, token: token),
    );
  }

  @override
  ConsumerState<SendTokenSheet> createState() => _SendTokenSheetState();
}

class _SendTokenSheetState extends ConsumerState<SendTokenSheet> {
  final TextEditingController _to = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  String? _addressError;
  String? _amountError;
  double? _balance;

  bool get _isTron => widget.chain == ChainType.tron;
  int get _displayDecimals =>
      widget.token.decimals > 8 ? 8 : widget.token.decimals;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// 进入时拉取该代币余额（ERC-20 / TRC-20，需设定 RPC），失败就当作没有显示。
  Future<void> _loadBalance() async {
    final settings = ref.read(settingsProvider);
    final identity = ref.read(sessionProvider).identity;
    final tronAddress = identity?.tronAddress ?? identity?.address ?? '';
    if (settings.rpcFor(widget.chain).isEmpty || identity == null) return;
    final balance = await TxService.tokenBalance(
      chain: widget.chain,
      rpcUrl: settings.rpcFor(widget.chain),
      contractAddress: widget.token.address,
      ownerAddress: _isTron ? tronAddress : identity.address,
      decimals: widget.token.decimals,
    );
    if (mounted) setState(() => _balance = balance);
  }

  double? get _amountValue {
    final raw = _amount.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String _errorText(String code) => switch (code) {
        'invalid-address' => context.s.walletErrInvalidAddress,
        'invalid-amount' => context.s.walletErrInvalidAmount,
        'insufficient-funds' => context.s.walletErrInsufficient,
        'no-rpc' => context.s.walletErrNoRpc,
        'no-identity' => context.s.walletErrNoRpc,
        'unsupported' => context.s.tokenErrTronToken,
        _ => context.s.walletErrNetwork,
      };

  String? _addressErrorFor(String address) {
    if (TxService.isValidAddress(widget.chain, address)) return null;
    final belongsElsewhere = ChainType.values
        .any((c) => c != widget.chain && TxService.isValidAddress(c, address));
    return belongsElsewhere
        ? context.s.walletErrChainMismatch
        : context.s.walletErrInvalidAddress;
  }

  ({String address, double amount})? _validate() {
    final s = context.s;
    final address = _to.text.trim();
    final amount = _amountValue;

    final addressOk = address.isNotEmpty &&
        TxService.isValidAddress(widget.chain, address);
    final amountOk = amount != null && amount > 0;

    setState(() {
      _addressError = address.isEmpty
          ? s.walletErrInvalidAddress
          : _addressErrorFor(address);
      _amountError = amountOk ? null : s.walletErrInvalidAmount;
    });
    if (!addressOk || !amountOk) return null;
    return (address: address, amount: amount);
  }

  Future<void> _scan() async {
    final raw = await context.push<String>('/scan?pick=1&chain=${widget.chain.id}');
    if (raw == null || !mounted) return;
    setState(() {
      _to.text = raw.trim();
      _addressError = null;
    });
  }

  Future<void> _confirmAndSend() async {
    final parsed = _validate();
    if (parsed == null) return;

    final s = context.s;
    final config = ChainConfig.of(widget.chain);
    final chainLabel = ChainSelector.labelOf(s, widget.chain);

    // 端点与链不符时硬挡（余额查得到、交易也送得出去，但会送错网）。
    final chainId = ref.read(walletInfoProvider).value?.chainId;
    if (config.isWrongChain(chainId)) {
      showAppSnack(context, s.walletRpcMismatch, danger: true);
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.walletSendConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Row(
                  label: s.walletSendNetwork,
                  value: '$chainLabel · ${widget.token.symbol}',
                ),
                const SizedBox(height: 12),
                _Row(label: s.walletSendTo, value: parsed.address),
                const SizedBox(height: 12),
                _Row(
                  label: s.walletAmount,
                  value:
                      '${Formatters.amount(parsed.amount, _displayDecimals)} '
                      '${widget.token.symbol}',
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

    // 发币前再验一次密码：解锁后私钥常驻内存，避免页面静默代签。
    if (!await authorizeWithPassword(context, ref) || !mounted) return;

    final result = await ref.read(walletSendProvider.notifier).sendToken(
          token: widget.token,
          toAddress: parsed.address,
          amount: parsed.amount,
        );
    if (!mounted) return;

    if (result == null) {
      final code = ref.read(walletSendProvider).error ?? 'network';
      showAppSnack(context, _errorText(code), danger: true);
      return;
    }
    _showSuccess(result);
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
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
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              Navigator.pop(context); // 关掉成功对话框
              Navigator.pop(context); // 关掉转帐表单
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
    final send = ref.watch(walletSendProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TokenIcon(token: widget.token, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.token.name.isEmpty
                            ? widget.token.symbol
                            : widget.token.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.token.symbol,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _to,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 1,
              maxLines: 2,
              onChanged: (_) {
                if (_addressError != null) setState(() => _addressError = null);
              },
              decoration: InputDecoration(
                labelText: s.walletSendTo,
                hintText: s.walletSendToHint,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                errorText: _addressError,
                suffixIcon: IconButton(
                  tooltip: s.walletScanAddress,
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
              decoration: InputDecoration(
                labelText: s.walletAmount,
                hintText: s.walletAmountHint,
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: widget.token.symbol,
                errorText: _amountError,
                helperText: _balance == null
                    ? null
                    : '${s.walletAvailable}: '
                        '${Formatters.amount(_balance, _displayDecimals)} '
                        '${widget.token.symbol}',
                helperStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            if (_balance != null && _balance! > 0) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _amount.text =
                        _balance!.toStringAsFixed(_displayDecimals);
                    setState(() => _amountError = null);
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 17),
                  label: Text(s.walletUseMax),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: send.busy ? null : _confirmAndSend,
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
    );
  }
}

/// 确认对话框中的一列「标签 / 值」。
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
