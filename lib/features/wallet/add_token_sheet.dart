import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/ethereum/tx_service.dart';
import '../../data/models/chain.dart';
import '../../data/models/token_def.dart';
import '../../data/tokens/token_providers.dart';
import '../../shared/feedback.dart';

/// 新增自订通证的底部表单。
///
/// 填写名称、符号、标准、精度与合约地址（图示 / 颜色可选），
/// 送出后写入 [customTokensProvider]（持久化于 shared_preferences）。
class AddTokenSheet extends ConsumerStatefulWidget {
  const AddTokenSheet({required this.chain, super.key});

  final ChainType chain;

  /// 以底部面板形式弹出。失败时不会改变任何状态。
  static void show(BuildContext context, ChainType chain) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => AddTokenSheet(chain: chain),
    );
  }

  @override
  ConsumerState<AddTokenSheet> createState() => _AddTokenSheetState();
}

class _AddTokenSheetState extends ConsumerState<AddTokenSheet> {
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  final _decimals = TextEditingController(text: '18');
  final _address = TextEditingController();
  final _icon = TextEditingController();
  final _color = TextEditingController();

  TokenStandard _standard = TokenStandard.erc20;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _decimals.dispose();
    _address.dispose();
    _icon.dispose();
    _color.dispose();
    super.dispose();
  }

  void _onStandardChanged(TokenStandard next) {
    setState(() {
      _standard = next;
      // NFT / 多维资产通常没有「数量精度」概念，预设 0。
      if (next != TokenStandard.erc20 && _decimals.text.trim() == '18') {
        _decimals.text = '0';
      } else if (next == TokenStandard.erc20 && _decimals.text.trim() == '0') {
        _decimals.text = '18';
      }
    });
  }

  String? _validate() {
    final s = context.s;
    final name = _name.text.trim();
    final symbol = _symbol.text.trim();
    final address = _address.text.trim();
    final decimalsRaw = _decimals.text.trim();

    if (name.isEmpty || symbol.isEmpty) return s.tokenErrNameSymbol;
    if (address.isEmpty || !TxService.isValidAddress(widget.chain, address)) {
      return s.tokenInvalidAddress;
    }
    final decimals = int.tryParse(decimalsRaw);
    if (decimals == null || decimals < 0 || decimals > 36) {
      return s.tokenInvalidDecimals;
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final token = TokenDef(
      name: _name.text.trim(),
      symbol: _symbol.text.trim(),
      standard: _standard,
      decimals: int.parse(_decimals.text.trim()),
      address: _address.text.trim(),
      icon: _icon.text.trim(),
      color: _color.text.trim(),
      custom: true,
    );
    ref.read(customTokensProvider.notifier).add(widget.chain, token);
    if (mounted) {
      Navigator.pop(context);
      showAppSnack(context, context.s.tokenAdded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
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
            Text(
              s.tokenAddTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _name,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: s.tokenName,
                      hintText: 'USD Coin',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _symbol,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: s.tokenSymbol,
                      hintText: 'USDC',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              s.tokenStandard,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<TokenStandard>(
              segments: <ButtonSegment<TokenStandard>>[
                ButtonSegment<TokenStandard>(
                  value: TokenStandard.erc20,
                  label: Text(s.tokenTypeErc20),
                ),
                ButtonSegment<TokenStandard>(
                  value: TokenStandard.erc721,
                  label: Text(s.tokenTabErc721),
                ),
                ButtonSegment<TokenStandard>(
                  value: TokenStandard.erc1155,
                  label: Text(s.tokenTabErc1155),
                ),
              ],
              selected: <TokenStandard>{_standard},
              onSelectionChanged: (set) => _onStandardChanged(set.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _address,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: s.tokenContract,
                      hintText: '0x… / T…',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _decimals,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                    decoration: InputDecoration(
                      labelText: s.tokenDecimals,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _icon,
                    decoration: InputDecoration(
                      labelText: s.tokenIcon,
                      hintText: '💵',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _color,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: s.tokenColor,
                      hintText: '#2775CA',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(s.tokenAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
