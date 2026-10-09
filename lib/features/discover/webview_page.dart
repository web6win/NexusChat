import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/tron_address.dart';
import '../../data/models/chain.dart';
import '../../features/discover/bookmarks_provider.dart';
import '../../features/discover/dapp_bridge.dart';
import '../../features/discover/dapp_catalog.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';

/// 应用内浏览器：内嵌 WebView + 手动输入网址。
///
/// 两种进入方式：
/// - 扫码得到网址 → 直接载入 [WebViewPage.url]；
/// - 发现页的「浏览器」工具 → 网址为空白，先显示起始页，由使用者输入网址。
///
/// 工具栏提供：扫一扫（把网址带回本页）、收藏、钱包（钱包插件状态）、重新整理。
///
/// 同时向页面注入 `window.ethereum`（EIP-1193 provider），把网站的钱包请求
/// 桥接到 App 本地钱包：连接 / 签名 / 发交易 / 切链，其余只读 JSON-RPC 透明
/// 转发到当前链的节点（见 [DappWalletBridge]）。
///
/// 网页版（Web build）没有内嵌 WebView 的实作，此时改用系统浏览器开启网址，
/// 避免在网页版渲染 WebViewWidget 直接崩渍。
class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({required this.url, super.key});

  /// 已解码、要载入的 http(s) 网址；空白表示由使用者输入。
  final String url;

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  WebViewController? _controller;
  DappWalletBridge? _bridge;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  bool _started = false;
  String _current = '';
  String? _lastErrorUrl;
  String? _tronLib;

  bool get _valid {
    final scheme = Uri.tryParse(widget.url)?.scheme;
    return scheme == 'http' || scheme == 'https';
  }

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) {
      _address.text = widget.url;
      _current = widget.url;
    }
    // 网页版没有内嵌 WebView 实作，不建立 controller，改走系统浏览器。
    if (kIsWeb) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        kDappChannel,
        onMessageReceived: (message) => _bridge?.handleRaw(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _progress.value = p,
          onPageStarted: (url) {
            _syncAddress(url);
            unawaited(_inject());
          },
          onPageFinished: (url) {
            _syncAddress(url);
            unawaited(_inject());
          },
          onWebResourceError: (error) {
            // 只有「整页（主框架）」载入失败才提示。favicon、图片、脚本等
            // 子资源的错误非常常见，若一并提示就会变成一直跳错误讯息。
            if (error.isForMainFrame != true) return;
            final failing = error.url ?? '';
            // 同一个网址只提示一次，避免重试时重复弹。
            if (failing.isNotEmpty && failing == _lastErrorUrl) return;
            _lastErrorUrl = failing;
            if (mounted) {
              showAppSnack(context, context.s.scanOpenFailed, danger: true);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme ?? '';
            // 非 http(s) 协定（tel: / mailto: / intent: 等）交给系统处理，
            // 不留在 WebView 里，避免卡死或解析失败。
            if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
              unawaited(
                launchUrl(uri!, mode: LaunchMode.externalApplication)
                    .then<void>((_) {}, onError: (_, stack) {}),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (_valid) {
      _started = true;
      unawaited(controller.loadRequest(Uri.parse(widget.url)));
    }

    _controller = controller;
    _bridge = DappWalletBridge(
      ref: ref,
      context: context,
      controller: controller,
    );
  }

  /// 页面换页时同步网址列；使用者正在输入时不覆写，免得打一半被洗掉。
  void _syncAddress(String url) {
    if (url.isEmpty) return;
    _current = url;
    if (!_addressFocus.hasFocus) _address.text = url;
  }

  /// 注入钱包 provider：依目前选择的链决定注入哪一种。
  ///
  /// - TRON → `window.tronWeb` / `window.tronLink`（TronLink 相容）
  /// - 其余 EVM 链 → `window.ethereum`（EIP-1193）
  ///
  /// 每次导航都重新注入，确保新文档也有。
  Future<void> _inject() async {
    final controller = _controller;
    if (controller == null) return;
    final chain = ref.read(settingsProvider).chain;
    if (chain != ChainType.tron) {
      // EVM 链：注入 EIP-1193 provider。
      await controller.runJavaScript(kDappProviderJs).catchError((_) {});
      return;
    }
    // 波场：先注入内嵌的 tronWeb 函式库，再注入我们的 TronLink 相容层。
    // 顺序很重要 —— 相容层需要 window.TronWeb 已经存在才能建立实例。
    final lib = await _loadTronLib();
    if (lib != null) {
      await controller.runJavaScript(lib).catchError((_) {});
    }
    final identity = ref.read(coreProvider).identity;
    final tron = identity?.tronAddress ?? '';
    await controller
        .runJavaScript(
          tronProviderJs(
            address: tron,
            // tronWeb 的 setAddress / defaultAddress 需要 41 开头的 hex 形式。
            addressHex: tron.isEmpty ? '' : TronAddress.toHex(tron),
            host: ref.read(settingsProvider).rpcFor(ChainType.tron),
          ),
        )
        .catchError((_) {});
  }

  /// 读取并快取内嵌的 tronWeb 函式库（约 900 KB，只从 assets 读一次）。
  Future<String?> _loadTronLib() async {
    final cached = _tronLib;
    if (cached != null) return cached;
    try {
      final lib = await rootBundle.loadString('assets/tronweb/TronWeb.js');
      _tronLib = lib;
      return lib;
    } catch (_) {
      // 读不到就回退：相容层会尝试从 CDN 载入。
      return null;
    }
  }

  /// 载入网址列里的网址：没写协定就补 https://，让使用者能直接打 example.com。
  Future<void> _goTo(String input) async {
    final s = context.s;
    var text = input.trim();
    if (text.isEmpty) return;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (mounted) showAppSnack(context, s.scanOpenFailed, danger: true);
      return;
    }

    final url = uri.toString();
    _address.text = url;
    _current = url;
    _lastErrorUrl = null;
    _addressFocus.unfocus();

    if (kIsWeb) {
      // 网页版改用系统浏览器开启。
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnack(context, s.scanOpenFailed, danger: true);
      }
      return;
    }

    final controller = _controller;
    if (controller == null) return;
    await controller.loadRequest(uri);
    if (mounted) setState(() => _started = true);
    unawaited(_inject());
  }

  /// 扫一扫：用「挑选网址」模式，把扫到的网址带回这一页直接打开。
  Future<void> _scan() async {
    final result = await context.push<String>('/scan?pickUrl=1');
    if (!mounted || result == null || result.isEmpty) return;
    await _goTo(result);
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BookmarksSheet(
        currentUrl: _current,
        onOpen: (url) {
          Navigator.of(ctx).pop();
          unawaited(_goTo(url));
        },
      ),
    );
  }

  void _showWallet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _WalletSheet(
        connected: _bridge?.connected ?? false,
        onDisconnect: () {
          _bridge?.disconnect();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // 切换链（EVM ↔ 波场）时改用对应的钱包 provider，并重整页面，
    // 让 DApp 重新侦测到正确的钱包物件。
    ref.listen<ChainType>(
      settingsProvider.select((value) => value.chain),
      (previous, next) {
        unawaited(_inject());
        _controller?.reload();
      },
    );
    // 起始页（默认页）要随钱包当前网络切换，因此这里直接 watch，
    // 切链时重建主页、列出对应链常用的 DApp。
    final chain = ref.watch(settingsProvider.select((value) => value.chain));
    final showWeb = !kIsWeb && _controller != null && _started;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: _AddressBar(
          controller: _address,
          focusNode: _addressFocus,
          hint: s.browserAddressHint,
          onSubmit: _goTo,
        ),
        actions: <Widget>[
          // 网页内才常驻「刷新」；其余操作收入「⋯」菜单，避免把网址框挤窄。
          if (showWeb)
            IconButton(
              tooltip: s.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
            ),
          PopupMenuButton<String>(
            tooltip: s.more,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'home':
                  setState(() {
                    // 回到默认页：隐藏 WebView、清空网址列。
                    _started = false;
                    _address.text = '';
                    _current = '';
                  });
                case 'scan':
                  _scan();
                case 'bookmarks':
                  _showBookmarks();
                case 'wallet':
                  _showWallet();
              }
            },
            itemBuilder: (ctx) {
              final items = <PopupMenuEntry<String>>[
                if (showWeb)
                  PopupMenuItem<String>(
                    value: 'home',
                    child: _MenuItem(
                      icon: Icons.home_rounded,
                      label: s.browserHome,
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'scan',
                  child: _MenuItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: s.scanTitle,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'bookmarks',
                  child: _MenuItem(
                    icon: Icons.bookmarks_rounded,
                    label: s.browserBookmark,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'wallet',
                  child: _MenuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: s.browserWallet,
                  ),
                ),
              ];
              return items;
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ValueListenableBuilder<int>(
            valueListenable: _progress,
            builder: (ctx, value, child) =>
                value >= 100 || value == 0
                    ? const SizedBox.shrink()
                    : const LinearProgressIndicator(minHeight: 2),
          ),
        ),
      ),
      body: showWeb ? WebViewWidget(controller: _controller!) : _buildHome(s, chain),
    );
  }

  /// 默认页（起始页）：尚未载入任何网页（发现页进入、或按「主页」）时显示。
  ///
  /// 依 [chain]（钱包当前网络）列出该链常用的 DApp，点选即开启；
  /// 切链时由 [build] 的 watch 自动重建。网页版没有内嵌 WebView，
  /// 点选会改用系统浏览器开启。
  Widget _buildHome(Strings s, ChainType chain) {
    final theme = Theme.of(context);
    final dapps = dappsFor(chain);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.explore_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              s.browserHomeTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          s.browserHomeHint,
          style: TextStyle(
            fontSize: 12.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.public_rounded,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    chainLabel(chain),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (kIsWeb) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            s.browserWebNote,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 74,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: dapps.length,
          itemBuilder: (ctx, i) => _DappTile(
            d: dapps[i],
            onTap: () => unawaited(_goTo(dapps[i].url)),
          ),
        ),
      ],
    );
  }
}

/// 默认页里的单个 DApp 入口：彩色图标 + 名称 + 分类/域名。
class _DappTile extends StatelessWidget {
  const _DappTile({required this.d, required this.onTap});

  final DappEntry d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(d.url)?.host ?? d.url;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: d.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(d.icon, color: d.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.category ?? host,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具栏「⋯」菜单里的单一项：图标 + 文字。
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      );
}

/// 网址列：圆角输入框，输入后按键盘的「前往」即可载入。
class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.language_rounded, size: 16, color: dim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmit,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13.5, color: dim),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏面板：加入当前页面、点选开启、删除。
class _BookmarksSheet extends ConsumerWidget {
  const _BookmarksSheet({required this.currentUrl, required this.onOpen});

  final String currentUrl;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final bookmarks = ref.watch(bookmarksProvider);
    final already = bookmarks.any((b) => b.url == currentUrl);
    final canAdd = currentUrl.isNotEmpty && !already;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              s.browserBookmark,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (canAdd) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(bookmarksProvider.notifier)
                      .add(_bookmarkFor(currentUrl));
                  if (context.mounted) {
                    showAppSnack(context, s.browserBookmarkAdded);
                  }
                },
                icon: const Icon(Icons.star_border_rounded, size: 18),
                label: Text(s.browserAddBookmark),
              ),
            ],
            const SizedBox(height: 8),
            if (bookmarks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    s.browserBookmarkEmpty,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              )
            else
              // 不用 Flexible：外层 Column 是 mainAxisSize.min（高度无上限），
              // Flexible 会拿到 unbounded 约束而报错，改用 maxHeight 限制。
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = bookmarks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.star_rounded, size: 18),
                      title: Text(
                        item.title ?? item.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onOpen(item.url),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                        onPressed: () async {
                          await ref
                              .read(bookmarksProvider.notifier)
                              .remove(item.url);
                          if (context.mounted) {
                            showAppSnack(context, s.browserBookmarkRemoved);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Bookmark _bookmarkFor(String url) => Bookmark(
        url: url,
        title: Uri.tryParse(url)?.host ?? url,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

/// 钱包面板（钱包插件）：显示地址、目前网路与本网站的连线状态。
class _WalletSheet extends ConsumerWidget {
  const _WalletSheet({required this.connected, required this.onDisconnect});

  final bool connected;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final identity = ref.watch(sessionProvider).identity;
    final settings = ref.watch(settingsProvider);
    final address = identity?.address ?? '';
    final shortAddress = address.length > 12
        ? '${address.substring(0, 8)}…${address.substring(address.length - 6)}'
        : address;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              s.browserWallet,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    s.dappAccount,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
                Expanded(
                  child: Text(
                    shortAddress.isEmpty ? '—' : shortAddress,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                if (address.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: address));
                      if (context.mounted) showAppSnack(context, s.copied);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    s.dappNetwork,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
                Expanded(
                  child: DropdownButton<ChainType>(
                    value: settings.chain,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(ref
                          .read(settingsProvider.notifier)
                          .setChain(value));
                    },
                    items: <DropdownMenuItem<ChainType>>[
                      for (final chain in ChainType.values)
                        DropdownMenuItem<ChainType>(
                          value: chain,
                          child: Text(chainLabel(chain)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(
                  connected
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  size: 17,
                  color: connected ? AppColors.success : theme.hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected
                        ? s.browserWalletConnected
                        : s.browserWalletNotConnected,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            if (connected) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onDisconnect,
                child: Text(s.browserDisconnect),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
