import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chain.dart';
import '../../data/models/token_def.dart';
import '../../data/tokens/token_providers.dart';
import '../../data/tokens/token_tx_history.dart';
import '../../shared/feedback.dart';
import 'add_token_sheet.dart';
import 'send_token_sheet.dart';

/// 通證面板：在轉帳 / 收款按鈕下方，依目前鏈顯示常用通證。
///
/// 以三個 Tab 分類呈現：代幣（ERC-20）、NFT（ERC-721）、資產集（ERC-1155），
/// 並提供「新增自訂通證」入口。內建清單來自 `assets/tokens.json`，
/// 自訂清單來自 `customTokensProvider`（持久化於 shared_preferences）。
class TokenPanel extends ConsumerWidget {
  const TokenPanel({required this.chain, super.key});

  final ChainType chain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final builtInAsync = ref.watch(builtInTokensProvider);
    final custom = ref.watch(customTokensProvider)[chain] ?? const <TokenDef>[];

    final builtIn = builtInAsync.valueOrNull?[chain] ?? const <TokenDef>[];
    final all = <TokenDef>[...builtIn, ...custom];

    final erc20 = all.where((t) => t.standard == TokenStandard.erc20).toList();
    final erc721 = all.where((t) => t.standard == TokenStandard.erc721).toList();
    final erc1155 =
        all.where((t) => t.standard == TokenStandard.erc1155).toList();

    final maxCount = <int>[erc20.length, erc721.length, erc1155.length]
        .reduce(max);
    final viewHeight = maxCount == 0
        ? 104.0
        : (maxCount * 70.0 + 12).clamp(104.0, 4 * 70.0 + 12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
            child: Row(
              children: <Widget>[
                Text(
                  s.walletTokens,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: s.tokenAdd,
                  onPressed: () => AddTokenSheet.show(context, chain),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TabBar(
                        isScrollable: false,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        tabs: <Widget>[
                          Tab(text: s.tokenTabErc20),
                          Tab(text: s.tokenTabErc721),
                          Tab(text: s.tokenTabErc1155),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (builtInAsync.isLoading)
                      const SizedBox(
                        height: 104,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: viewHeight,
                        child: TabBarView(
                          children: <Widget>[
                            _TokenList(
                              tokens: erc20,
                              onTap: (t) => _showDetail(context, ref, chain, t),
                            ),
                            _TokenList(
                              tokens: erc721,
                              onTap: (t) => _showDetail(context, ref, chain, t),
                            ),
                            _TokenList(
                              tokens: erc1155,
                              onTap: (t) => _showDetail(context, ref, chain, t),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    ChainType chain,
    TokenDef token,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => TokenDetailSheet(chain: chain, token: token),
    );
  }
}

/// 單一 Tab 內的通證清單；沒有任何通證時顯示空狀態。
class _TokenList extends StatelessWidget {
  const _TokenList({required this.tokens, required this.onTap});

  final List<TokenDef> tokens;
  final ValueChanged<TokenDef> onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (tokens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.token_outlined,
                size: 30,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 10),
              Text(
                s.tokenEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          _TokenTile(token: tokens[index], onTap: () => onTap(tokens[index])),
    );
  }
}

/// 一個通證的列表項：圖示 + 名稱 + 符號 + 合約地址（可複製）。
class _TokenTile extends StatelessWidget {
  const _TokenTile({required this.token, required this.onTap});

  final TokenDef token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: TokenIcon(token: token, size: 38),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              token.name.isEmpty ? token.symbol : token.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              token.symbol,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
      subtitle: token.address.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                Did.shortAddress(token.address, head: 8, tail: 8),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
      trailing: token.custom
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.s.tokenCustom,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            )
          : null,
    );
  }
}

/// 通證圖示：圓形底色 + emoji 或符號首字母。
class TokenIcon extends StatelessWidget {
  const TokenIcon({required this.token, this.size = 38, super.key});

  final TokenDef token;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(token);
    final label = token.icon?.isNotEmpty == true
        ? token.icon!
        : (token.symbol.isNotEmpty ? token.symbol[0] : '?');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color, color.withValues(alpha: 0.72)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 由通證的 `color` 欄位解析底色，解析失敗時退回品牌色。
Color _colorOf(TokenDef token) {
  final raw = token.color;
  if (raw != null) {
    final hex = raw.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
  }
  return AppColors.brand;
}

/// 通證標準的中文標籤。
String tokenStandardLabel(Strings s, TokenStandard standard) =>
    switch (standard) {
      TokenStandard.erc20 => s.tokenTypeErc20,
      TokenStandard.erc721 => s.tokenTypeErc721,
      TokenStandard.erc1155 => s.tokenTypeErc1155,
      TokenStandard.native => s.tokenTypeNative,
    };

/// 通證的區塊瀏覽器連結（合約地址不為空時才有意義）。
String tokenExplorerUrl(ChainType chain, String address) {
  if (address.isEmpty) return '';
  if (chain == ChainType.tron) {
    return 'https://tronscan.org/#/token20/$address';
  }
  return 'https://${ChainConfig.of(chain).explorerHost}/token/$address';
}

/// 通證詳情底部面板：名稱、標準、精度、合約地址，並可複製 / 查看瀏覽器 /
/// 移除（自訂通證）。
class TokenDetailSheet extends ConsumerWidget {
  const TokenDetailSheet({
    required this.chain,
    required this.token,
    super.key,
  });

  final ChainType chain;
  final TokenDef token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final explorer = tokenExplorerUrl(chain, token.address);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            TokenIcon(token: token, size: 60),
            const SizedBox(height: 14),
            Text(
              token.name.isEmpty ? token.symbol : token.name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              token.symbol,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  _DetailRow(label: s.tokenStandard, value: tokenStandardLabel(s, token.standard)),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: s.tokenDecimals,
                    value: token.decimals.toString(),
                  ),
                  if (token.address.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        SizedBox(
                          width: 88,
                          child: Text(
                            s.tokenContract,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            token.address,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 發送入口：僅可轉帳的 ERC-20 提供「發送」；NFT 明確標注不可轉帳。
            if (token.standard == TokenStandard.erc20 &&
                token.address.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => SendTokenSheet.show(context, chain, token),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(s.walletSend),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.lock_outline_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.tokenNotTransferable,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 本地發送記錄（ERC-20 / TRC-20 通用）。
            if (token.standard == TokenStandard.erc20 &&
                token.address.isNotEmpty)
              _TokenHistorySection(chain: chain, contract: token.address),
            const SizedBox(height: 16),
            if (token.address.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: token.address),
                        );
                        if (context.mounted) {
                          showAppSnack(context, s.copied);
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(s.tokenCopyContract),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(explorer);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(s.tokenViewExplorer),
                    ),
                  ),
                ],
              ),
            ],
            if (token.custom) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(s.tokenRemove),
                            content: Text(s.tokenRemoveConfirm),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(s.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(s.tokenRemove),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (!confirmed || !context.mounted) return;
                    ref
                        .read(customTokensProvider.notifier)
                        .remove(chain, token.address);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.danger),
                  label: Text(
                    s.tokenRemove,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 詳情頁裡的「發送記錄」：列出本 App 對該通證發起的轉帳（本地儲存）。
class _TokenHistorySection extends ConsumerWidget {
  const _TokenHistorySection({
    required this.chain,
    required this.contract,
  });

  final ChainType chain;
  final String contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final all = ref.watch(tokenTxHistoryProvider);
    final records = all
        .where((r) =>
            r.chainId == chain.id &&
            r.contract.toLowerCase() == contract.toLowerCase())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.tokenHistoryTitle,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          Text(
            s.tokenHistoryEmpty,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          )
        else
          ...records.map((r) => _HistoryTile(record: r)),
      ],
    );
  }
}

/// 單一歷史記錄：金額 + 收款方 + 時間，點擊開瀏覽器或複製哈希。
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final TokenTxRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    return InkWell(
      onTap: () async {
        final url = record.explorerUrl;
        if (url != null && Uri.tryParse(url) != null) {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } else {
          await Clipboard.setData(ClipboardData(text: record.hash));
          if (context.mounted) showAppSnack(context, s.copied);
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_trim(record.amount)} ${record.symbol}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${s.walletSendTo} '
                    '${Did.shortAddress(record.toAddress, head: 8, tail: 8)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _fmtTime(record.timestamp),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 金額去掉多餘尾數零，便於在歷史列中顯示。
String _trim(double value) {
  final text = value.toStringAsFixed(6);
  if (!text.contains('.')) return text;
  return text
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

/// 時間戳記轉成 `YYYY-MM-DD HH:mm`。
String _fmtTime(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final p = (int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

/// 詳情面板中的一列「標籤 / 值」。
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
