import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../features/discover/dapp_bridge.dart';
import '../../shared/feedback.dart';

/// 应用内浏览器：内嵌 WebView + 手动输入网址。
///
/// 两种进入方式：
/// - 扫码得到网址 → 直接载入 [WebViewPage.url]；
/// - 发现页的「浏览器」工具 → 网址为空白，先显示起始页，由使用者输入网址。
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

  bool get _valid {
    final scheme = Uri.tryParse(widget.url)?.scheme;
    return scheme == 'http' || scheme == 'https';
  }

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) _address.text = widget.url;
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
            _inject();
          },
          onPageFinished: (url) {
            _syncAddress(url);
            _inject();
          },
          onWebResourceError: (error) {
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
    if (url.isEmpty || _addressFocus.hasFocus) return;
    _address.text = url;
  }

  /// 向页面注入 EIP-1193 provider。每次导航都重新注入，确保新文档也有。
  void _inject() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.runJavaScript(kDappProviderJs).catchError((_) {}));
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

    _address.text = uri.toString();
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
    _inject();
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
          if (showWeb)
            IconButton(
              tooltip: s.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
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
      body: showWeb ? WebViewWidget(controller: _controller!) : _buildStart(s),
    );
  }

  /// 起始页：还没有载入任何网页（发现页进入、或网址无效）时显示。
  Widget _buildStart(Strings s) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.language_rounded,
              size: 46,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              s.browserStartHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (kIsWeb) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                s.browserWebNote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
                hintStyle:
                    TextStyle(fontSize: 13.5, color: dim.withValues(alpha: 0.7)),
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
