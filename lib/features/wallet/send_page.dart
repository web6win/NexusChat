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

/// 轉帳頁：輸入收款地址與金額 → 二次確認 → 廣播交易。
///
/// 只支援原生代幣（ETH / TRX），不含 ERC-20 / TRC-20。
///
/// 「目前在哪一條鏈上轉帳」是這裡最重要的資訊 —— 轉錯鏈等於丟錢，
/// 因此頁面頂端是獨立且醒目的網路卡，並可就地切換；收款地址也必須
/// 通過**目前這條鏈**的格式驗證（掃碼帶來的鏈則會自動切過去）。
class SendPage extends ConsumerStatefulWidget {
  const SendPage({
    this.chain,
    this.initialAddress,
    super.key,
  });

  /// 進入時要套用的鏈（掃碼進來時由 QR Code 決定）。
  ///
  /// `null` 表示沿用設定值。指定的話會同步寫回設定，讓轉帳執行時
  /// 使用的鏈與畫面上顯示的鏈永遠一致。
  final ChainType? chain;

  /// 預填的收款資料（掃碼帶入）。
  ///
  /// 可以是純地址，也可以是完整的支付 URI
  /// （`ethereum:0x…?value=…` / `tron:T…?amount=…`）—— 後者連同金額與鏈
  /// 一起帶入，讓使用者掃完只要按確認。
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

    // 掃碼帶入的可能是純地址，也可能是帶金額與鏈的支付 URI。
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

    // 目標鏈：優先採用掃碼內容指定的鏈（地址格式已經限定它只能是那條鏈）。
    final target = request?.chain ?? widget.chain;
    if (target != null) {
      // 設定是唯一的真值來源（轉帳時讀的也是它），所以進入時就對齊，
      // 避免畫面顯示 A 鏈、實際送出 B 鏈。
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

  /// 把錯誤代碼映射成可讀文案。
  String _errorText(String code) => switch (code) {
        'invalid-address' => context.s.walletErrInvalidAddress,
        'invalid-amount' => context.s.walletErrInvalidAmount,
        'insufficient-funds' => context.s.walletErrInsufficient,
        'no-rpc' => context.s.walletErrNoRpc,
        _ => context.s.walletErrNetwork,
      };

  /// 地址錯誤要能分辨「寫錯」與「別條鏈的地址」——後者的處理方式不同。
  String? _addressErrorFor(ChainType chain, String address) {
    if (TxService.isValidAddress(chain, address)) return null;
    final belongsElsewhere = ChainType.values
        .any((c) => c != chain && TxService.isValidAddress(c, address));
    return belongsElsewhere
        ? context.s.walletErrChainMismatch
        : context.s.walletErrInvalidAddress;
  }

  /// 驗證並回傳 (address, amount)；不合法時回傳 null 並設好錯誤訊息。
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

  /// 切換轉帳網路：改的是設定本身，因此餘額與實際送出的鏈會一起跟上。
  Future<void> _switchChain(ChainType next) async {
    if (next == ref.read(settingsProvider).chain) return;
    await ref.read(settingsProvider.notifier).setChain(next);
    if (!mounted) return;
    // 已填的位址可能屬於別條鏈，切換後立刻重新檢視。
    final address = _to.text.trim();
    setState(() {
      _addressError =
          address.isEmpty ? null : _addressErrorFor(next, address);
    });
  }

  /// 開啟掃碼頁（挑選地址模式），把結果填回表單。
  Future<void> _scan(ChainType chain) async {
    final raw = await context.push<String>('/scan?pick=1&chain=${chain.id}');
    if (raw == null || !mounted) return;
    await _applyScanned(raw, chain);
  }

  /// 套用掃碼結果：地址必填，金額與鏈由 QR Code 決定（鏈不同就切過去）。
  Future<void> _applyScanned(String raw, ChainType current) async {
    final s = context.s;
    // 先以目前鏈解，失敗再讓它自己推斷（例如在波場頁掃到 0x 地址）。
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

  /// 金額填回輸入框時去掉多餘的尾數零（1.500000 → 1.5）。
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

    // 二次確認：鏈上交易不可撤回，先讓使用者核對網路、地址與金額。
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
                  // 全名 + 代號一起核對，避免把 CNT 看成 ETH 之類的誤會。
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
              // 從掃碼頁進來時返回堆疊可能只有這一頁，pop 不掉就回錢包。
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

    // 唯一的真值來源：設定裡的鏈。畫面、餘額與實際送出的鏈都讀它。
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
              // -------------------------------------------- 目前轉帳網路
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

/// 轉帳頁頂端的「目前轉帳網路」卡。
///
/// 獨立成一塊、放在所有輸入之前：轉帳前第一件要看清楚的事就是「現在
/// 在哪條鏈上」。右側的切換器與錢包頁共用設定，切了就整頁一起更新。
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
    // 有 chainId 就顯示 chainId（最能代表「哪一條鏈」），否則退回端點。
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
          // 端點填錯時（例如把 Base 的 RPC 貼到以太坊），chainId 會對不上：
          // 餘額查得到、交易也送得出去，只是送到錯的網路上 —— 必須擋在這裡。
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
