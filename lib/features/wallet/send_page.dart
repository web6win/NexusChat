import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/ethereum/tx_service.dart';
import '../../data/models/chain.dart';
import '../../shared/layout.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';

/// 轉帳頁：輸入收款地址與金額 → 二次確認 → 廣播交易。
///
/// 只支援原生代幣（ETH / TRX），不含 ERC-20 / TRC-20。
class SendPage extends ConsumerStatefulWidget {
  const SendPage({required this.chain, super.key});

  final ChainType chain;

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  final TextEditingController _to = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  String? _addressError;
  String? _amountError;

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

  /// 把錯誤代碼映射成可讀文案。
  String _errorText(String code) => switch (code) {
        'invalid-address' => context.s.walletErrInvalidAddress,
        'invalid-amount' => context.s.walletErrInvalidAmount,
        'insufficient-funds' => context.s.walletErrInsufficient,
        'no-rpc' => context.s.walletErrNoRpc,
        _ => context.s.walletErrNetwork,
      };

  /// 驗證並回傳 (address, amount)；不合法時回傳 null 並設好錯誤訊息。
  ({String address, double amount})? _validate() {
    final s = context.s;
    final address = _to.text.trim();
    final amount = _amountValue;

    final addressOk =
        address.isNotEmpty && TxService.isValidAddress(widget.chain, address);
    final amountOk = amount != null && amount > 0;

    setState(() {
      _addressError = addressOk ? null : s.walletErrInvalidAddress;
      _amountError = amountOk ? null : s.walletErrInvalidAmount;
    });
    if (!addressOk || !amountOk) return null;
    return (address: address, amount: amount);
  }

  Future<void> _confirmAndSend() async {
    final parsed = _validate();
    if (parsed == null) return;

    final s = context.s;
    final config = ChainConfig.of(widget.chain);

    // 二次確認：鏈上交易不可撤回，先讓使用者核對地址與金額。
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.walletSendConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
              Navigator.pop(context);
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
    final config = ChainConfig.of(widget.chain);
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
                ),
              ),
              const SizedBox(height: 18),
              // ---------------------------------------------------- 金額
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
                      // 保留一點手續費空間，避免「全部」之後必然失敗。
                      final usable = widget.chain == ChainType.tron
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
              const SizedBox(height: 16),
              // 鏈上交易不可撤回的提醒。
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline_rounded,
                        size: 17, color: AppColors.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${settings.chainName} · ${config.symbol}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 確認對話框中的一列「標籤 / 值」。
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
