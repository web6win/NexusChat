import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../features/discover/dapp_bridge.dart';
import '../../shared/feedback.dart';

/// 应用内浏览器：以 WebView 载入扫码得到的网址，取代「用外部浏览器开启」。
///
/// 同时向页面注入 `window.ethereum`（EIP-1193 provider），把网站的钱包请求
/// 桥接到 App 本地钱包：连接 / 签名 / 发交易 / 切链，其余只读 JSON-RPC 透明
/// 转发到当前链的节点（见 [DappWalletBridge]）。
class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({required this.url, super.key});

  /// 已解码、要载入的 http(s) 网址。
  final String url;

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  WebViewController? _controller;
  DappWalletBridge? _bridge;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  final ValueNotifier<String> _currentUrl = ValueNotifier<String>('');

  bool get _valid {
    final scheme = Uri.tryParse(widget.url)?.scheme;
    return scheme == 'http' || scheme == 'https';
  }

  @override
  void initState() {
    super.initState();
    _currentUrl.value = widget.url;
    if (!_valid) return;

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
            _currentUrl.value = url;
            _inject();
          },
          onPageFinished: (url) {
            _currentUrl.value = url;
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
      )
      ..loadRequest(Uri.parse(widget.url));

    _controller = controller;
    _bridge = DappWalletBridge(
      ref: ref,
      context: context,
      controller: controller,
    );
  }

  /// 向页面注入 EIP-1193 provider。每次导航都重新注入，确保新文档也有。
  void _inject() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.runJavaScript(kDappProviderJs).catchError((_) {}));
  }

  @override
  void dispose() {
    _progress.dispose();
    _currentUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: _currentUrl,
          builder: (ctx, url, child) {
            final host = Uri.tryParse(url)?.host ?? url;
            return Text(
              host.isEmpty ? s.scanTitle : host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: <Widget>[
          if (_controller != null)
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
      body: _valid && _controller != null
          ? WebViewWidget(controller: _controller!)
          : _buildInvalid(s),
    );
  }

  Widget _buildInvalid(Strings s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s.scanOpenFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );
}
