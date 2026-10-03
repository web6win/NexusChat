import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../data/models/chain.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import '../wallet/chain_selector.dart';

/// 區塊鏈：選擇鏈 + 該鏈的 RPC 端點。拆自原本擠在同一頁的設定。
class BlockchainSettingsPage extends ConsumerStatefulWidget {
  const BlockchainSettingsPage({super.key});

  @override
  ConsumerState<BlockchainSettingsPage> createState() =>
      _BlockchainSettingsPageState();
}

class _BlockchainSettingsPageState extends ConsumerState<BlockchainSettingsPage> {
  late final TextEditingController _rpcUrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _rpcUrl = TextEditingController(text: settings.rpcFor(settings.chain));
  }

  /// 換鏈後把輸入框換成該鏈的端點，避免把 A 鏈的端點存到 B 鏈上。
  void _syncRpcField() {
    final settings = ref.read(settingsProvider);
    _rpcUrl.text = settings.rpcFor(settings.chain);
  }

  @override
  void dispose() {
    _rpcUrl.dispose();
    super.dispose();
  }

  /// 儲存「目前所選鏈」的 RPC 端點；留空表示還原成該鏈的預設值。
  Future<void> _saveRpc() async {
    final value = _rpcUrl.text.trim();
    await ref
        .read(settingsProvider.notifier)
        .setRpcFor(ref.read(settingsProvider).chain, value);
    if (!mounted) return;
    // 留空時會還原成預設端點，把結果回填給輸入框。
    setState(_syncRpcField);
    ref.invalidate(walletInfoProvider);
  }

  Widget _chainCard(BuildContext context, ChainType current, ChainType chain) {
    return ThemeOptionCard(
      label: ChainSelector.labelOf(context.s, chain),
      icon: ChainSelector.iconOf(chain),
      selected: current == chain,
      onTap: () async {
        await ref.read(settingsProvider.notifier).setChain(chain);
        if (!mounted) return;
        // 換鏈後輸入框要跟著換成該鏈的端點。
        setState(_syncRpcField);
        ref.invalidate(walletInfoProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.walletChain)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.walletChain,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 每行三張卡；鏈變多時自動多排一行，不用改版面。
                    // 用 IntrinsicHeight 讓同一行的卡片等高（鏈名長度不一）。
                    for (var row = 0;
                        row * 3 < ChainType.values.length;
                        row++)
                      Padding(
                        padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              for (var col = 0; col < 3; col++) ...<Widget>[
                                if (col > 0) const SizedBox(width: 10),
                                if (row * 3 + col < ChainType.values.length)
                                  Expanded(
                                    child: _chainCard(
                                      context,
                                      settings.chain,
                                      ChainType.values[row * 3 + col],
                                    ),
                                  )
                                else
                                  // 最後一行不滿三張時補空位，維持左對齊。
                                  const Expanded(child: SizedBox.shrink()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      s.walletChainDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: s.settingsAdvanced,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _rpcUrl,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _saveRpc(),
                      decoration: InputDecoration(
                        // 標題帶上鏈名：端點是「哪一條鏈的」必須一眼看得出來。
                        labelText:
                            '${ChainSelector.labelOf(s, settings.chain)} · '
                            '${s.walletRpcUrl}',
                        prefixIcon: const Icon(Icons.cable_rounded),
                        helperText: s.walletRpcUrlHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saveRpc,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(s.save),
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
