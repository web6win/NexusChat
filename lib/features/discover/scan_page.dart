import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/crypto/did.dart';
import '../../data/ethereum/payment_uri.dart';
import '../../data/models/chain.dart';
import '../../features/wallet/chain_selector.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';

/// 扫一扫：以相机读取 QR Code。
///
/// 结果处理规则（依序判断）：
/// 1. 付款请求（`ethereum:0x…?value=…` / `tron:T…?amount=…`）→ 可直接转帐。
/// 2. DID / 0x 地址 / ENS 名称 → 加入联络人、转帐或复制。
/// 3. 网址（`http(s)://…` 或以网域开头的字串）→ 在应用内 WebView 新页面开启。
/// 4. 其他文字 → 显示内容并可复制。
///
/// 相机后端由 mobile_scanner 提供，仅支援 Android / iOS / macOS / 浏览器；
/// 其余平台（Windows、Linux）改为显示不支援提示，而不是让画面坏掉。
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({this.pickAddress = false, this.chain, super.key});

  /// 挑选模式：只把「收款地址 / 付款请求」回传给上一页（转帐页用），
  /// 不做加入联络人等其他动作。
  final bool pickAddress;

  /// 期望的链；扫到的内容若明显属于别条链，仍会回传，由转帐页提示并切换。
  final ChainType? chain;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  MobileScannerController? _controller;

  /// 是否正在处理某个扫描结果。处理期间停止辨识，避免同一个码反复触发。
  bool _busy = false;

  /// 目前平台是否有可用的相机后端。
  static bool get _cameraSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    if (_cameraSupported) {
      _controller = MobileScannerController(
        // 只认 QR Code：这个页面不会扫商品条码，限定格式可减少误判。
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        // 同一个码只回报一次，使用者不必担心镜头晃一下就连续触发。
        detectionSpeed: DetectionSpeed.noDuplicates,
        autoZoom: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || !mounted) return;
    final value = _firstValue(capture);
    if (value == null) return;

    _busy = true;
    await _controller?.stop();
    if (!mounted) return;
    await _handle(value);
  }

  static String? _firstValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }

  Future<void> _handle(String value) async {
    // 挑选模式（转帐页呼叫）：只收「可以当收款对象」的内容。
    if (widget.pickAddress) {
      await _pickAddress(value);
      return;
    }
    // 付款请求优先：`ethereum:0x…?value=…` 同时带地址与金额，比纯地址明确。
    final payment = PaymentUri.parse(value);
    if (payment != null) {
      await _showPaymentSheet(payment, value);
      return;
    }
    // 身份类内容优先于网址判断，否则 `name.eth` 会被当成一般网域开出去。
    if (_looksLikeIdentity(value)) {
      await _showIdentitySheet(value);
      return;
    }
    final uri = _asHttpUri(value);
    if (uri != null) {
      await _openLink(uri);
      return;
    }
    await _showTextSheet(value);
  }

  /// 挑选模式：把扫到的内容原样回传，由转帐页解析地址 / 金额 / 链。
  Future<void> _pickAddress(String value) async {
    final request = PaymentUri.fromScan(value, chain: widget.chain) ??
        PaymentUri.fromScan(value);
    if (request == null) {
      showAppSnack(context, context.s.scanPickInvalid, danger: true);
      await _resume();
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, value);
  }

  /// 带著扫到的内容前往转帐页。
  Future<void> _openSend(String value) async {
    final router = GoRouter.of(context);
    // DID 对转帐没有意义，换成地址；ENS 需要线上解析，维持原样让使用者处理。
    final target = Did.isEthrDid(value) ? Did.toAddress(value) : value;
    final chain = _sendChainFor(target);
    final query = Uri(queryParameters: <String, String>{
      'address': target,
      // 只有能确定时才指定链；0x 地址在以太坊与 Besu 都合法，交给使用者
      // 目前的选择，不要在背后偷偷换网路。
      if (chain != null) 'chain': chain.id,
    }).query;
    // push 而非 go：保留返回堆叠，转帐页才不会变成没有上一页的孤岛。
    router.push('/send?$query');
  }

  /// 扫到的内容属于哪一条链；不确定时回传 null（沿用设定）。
  ChainType? _sendChainFor(String value) {
    // 带 scheme 的付款请求已经写明是哪条链。
    final uri = PaymentUri.parse(value);
    if (uri != null) return uri.chain;
    final bare = PaymentUri.fromAddress(value);
    if (bare == null) return null;
    // T 开头只可能是 TRON；0x 则可能是任一条 EVM 链。
    return bare.chain == ChainType.tron ? ChainType.tron : null;
  }

  /// 扫到网址：原生端在应用内 WebView 新页面开启；Web 端改用浏览器新窗口。
  /// 从 WebView 返回后再恢复扫描，方便连续扫多个码。
  Future<void> _openLink(Uri uri) async {
    // Web 端没有 WebView 原生实现，也无法注入钱包 provider，
    // 因此改用外部浏览器在新窗口 / 新标签页打开。
    if (kIsWeb) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final router = GoRouter.of(context);
    // push 而非 go：WebView 叠在扫码页之上，关闭后回到扫码页。
    await router.push('/webview?url=${Uri.encodeComponent(uri.toString())}');
    if (!mounted) return;
    await _resume();
  }

  /// 扫到 NexusChat 身份（DID / 地址 / ENS）：加入联络人、转帐或复制。
  Future<void> _showIdentitySheet(String value) async {
    final s = context.s;
    final action = await _showResultSheet(
      title: s.scanResultTitle,
      label: _kindLabel(s, value),
      value: value,
      actions: <_SheetAction>[
        _SheetAction(
          id: 'contact',
          icon: Icons.person_add_alt_1_rounded,
          label: s.scanAddContact,
        ),
        _SheetAction(
          id: 'send',
          icon: Icons.send_rounded,
          label: s.scanPayAction,
        ),
        _SheetAction(id: 'copy', icon: Icons.copy_rounded, label: s.copy),
      ],
    );
    if (!mounted) return;

    switch (action) {
      case 'contact':
        await _addContactAndOpenChat(value);
        return;
      case 'send':
        await _openSend(value);
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: value));
        if (!mounted) return;
        showAppSnack(context, s.copied);
        await _resume();
        return;
      default:
        await _resume();
    }
  }

  /// 扫到付款请求（带 scheme 的支付 URI）：显示链别与金额，可直接转帐。
  Future<void> _showPaymentSheet(PaymentRequest request, String raw) async {
    final s = context.s;
    final config = ChainConfig.of(request.chain);
    final amount = request.amount;
    final summary = amount == null
        ? '${ChainSelector.labelOf(s, request.chain)}\n${request.address}'
        : '${ChainSelector.labelOf(s, request.chain)}\n${request.address}\n'
            '${Formatters.amount(amount, config.displayDecimals)} '
            '${config.symbol}';

    final action = await _showResultSheet(
      title: s.scanResultTitle,
      label: s.scanResultPayment,
      value: summary,
      actions: <_SheetAction>[
        _SheetAction(
          id: 'send',
          icon: Icons.send_rounded,
          label: s.scanPayAction,
        ),
        _SheetAction(id: 'copy', icon: Icons.copy_rounded, label: s.copy),
      ],
    );
    if (!mounted) return;

    if (action == 'send') {
      await _openSend(raw);
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: raw));
      if (!mounted) return;
      showAppSnack(context, s.copied);
    }
    await _resume();
  }

  /// 扫到其他文字：单纯显示内容并可复制。
  Future<void> _showTextSheet(String value) async {
    final s = context.s;
    final action = await _showResultSheet(
      title: s.scanResultTitle,
      label: s.scanResultText,
      value: value,
      actions: <_SheetAction>[
        _SheetAction(id: 'copy', icon: Icons.copy_rounded, label: s.copy),
      ],
    );
    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      showAppSnack(context, s.copied);
    }
    await _resume();
  }

  /// 共用的扫描结果面板。回传动作的 id，取消则回传 null。
  Future<String?> _showResultSheet({
    required String title,
    required String label,
    required String value,
    required List<_SheetAction> actions,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (sheetContext) {
        final s = sheetContext.s;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // 第一个动作是主要动作（实心），其余为次要（描边）。
                for (var i = 0; i < actions.length; i++) ...<Widget>[
                  if (i == 0)
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, actions[i].id),
                      icon: Icon(actions[i].icon),
                      label: Text(actions[i].label),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, actions[i].id),
                      icon: Icon(actions[i].icon),
                      label: Text(actions[i].label),
                    ),
                  if (i < actions.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(s.cancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 加入联络人后直接开启对话；加入失败则留在扫描页并提示原因。
  Future<void> _addContactAndOpenChat(String value) async {
    final router = GoRouter.of(context);
    final error = await ref.read(contactsProvider.notifier).add(value);
    if (!mounted) return;

    if (error != null) {
      showAppSnack(
        context,
        error == 'ens-failed' ? context.s.errorNetwork : context.s.contactsInvalidDid,
        danger: true,
      );
      await _resume();
      return;
    }

    // 先把 DID 解析出来（ENS 要靠刚写入的联络人回查），再离开页面。
    final did = _resolveDid(value);
    showAppSnack(context, context.s.contactsAdded);
    if (did != null) {
      // go 会直接换掉整个堆叠，扫码页也一并收掉。
      router.go('/chats?peer=${Uri.encodeComponent(did)}');
    } else {
      _exit(router);
    }
  }

  /// 离开扫码页：能 pop 就 pop，否则退回发现页（例如由深层连结直接进入）。
  ///
  /// 这里用捕获的 [router] 而非 `context`：呼叫当下页面可能已经开始销毁。
  void _exit(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/discover');
    }
  }

  void _close() => _exit(GoRouter.of(context));

  /// 解析扫描到的身份字串对应的 DID；ENS 需先加入联络人才能从状态回查。
  String? _resolveDid(String value) {
    if (Did.isEthrDid(value)) return value.toLowerCase();
    if (Did.isAddress(value)) return Did.fromAddress(value);
    final target = value.toLowerCase();
    for (final contact in ref.read(contactsProvider)) {
      if (contact.ens?.toLowerCase() == target) return contact.did;
    }
    return null;
  }

  /// 处理完（或使用者取消）后恢复扫描。
  Future<void> _resume() async {
    if (!mounted) return;
    _busy = false;
    await _controller?.start();
  }

  static bool _looksLikeIdentity(String value) =>
      Did.isEthrDid(value) || Did.isAddress(value) || Did.isEnsName(value);

  static String _kindLabel(Strings s, String value) {
    if (Did.isEthrDid(value)) return s.scanResultDid;
    if (Did.isEnsName(value)) return s.scanResultEns;
    return s.scanResultAddress;
  }

  /// 允许的网域：`example.com`、`sub.example.co.uk:8080/path?q=1`。
  /// 顶级域限定为 2 个以上的英文字母，避免把 `1.5` 这类纯数字误判成网址。
  static final RegExp _domainPattern = RegExp(
    r'^[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*'
    r'\.[a-zA-Z]{2,}(?::\d{1,5})?(?:[/?#]\S*)?$',
  );

  /// 把扫描到的字串转成可开启的 http(s) 网址；不是网址则回传 null。
  static Uri? _asHttpUri(String value) {
    final text = value.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;

    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      return (uri != null && uri.host.isNotEmpty) ? uri : null;
    }

    // 没有 scheme 的裸网域也视为网址，补上 https。
    if (_domainPattern.hasMatch(text)) return Uri.tryParse('https://$text');
    return null;
  }

  Future<void> _switchCamera() async {
    try {
      await _controller?.switchCamera();
    } catch (_) {
      // 只有单一镜头的装置会失败；维持目前镜头即可，不需要打扰使用者。
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: _cameraSupported ? _buildScanner(s) : _buildUnsupported(s),
    );
  }

  Widget _buildScanner(Strings s) {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MobileScanner(
          controller: controller,
          fit: BoxFit.cover,
          errorBuilder: (context, error) => _ScanErrorView(error: error),
          onDetect: _onDetect,
        ),
        const IgnorePointer(child: _ScanFrame()),
        SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: s.back,
                      onPressed: _close,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.pickAddress ? s.walletScanAddress : s.scanTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: controller,
                      builder: (context, state, _) {
                        final torchOn = state.torchState == TorchState.on;
                        final unavailable =
                            state.torchState == TorchState.unavailable;
                        return IconButton(
                          tooltip: s.scanTorch,
                          onPressed:
                              unavailable ? null : () => controller.toggleTorch(),
                          icon: Icon(
                            torchOn
                                ? Icons.flashlight_on_rounded
                                : Icons.flashlight_off_rounded,
                            color: unavailable
                                ? Colors.white38
                                : Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Column(
                  children: <Widget>[
                    Text(
                      widget.pickAddress ? s.scanPickHint : s.scanHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _switchCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      icon: const Icon(Icons.cameraswitch_rounded, size: 18),
                      label: Text(s.scanSwitchCamera),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupported(Strings s) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: s.back,
              onPressed: _close,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warning.withValues(alpha: 0.16),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.warning,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.scanUnsupportedTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.scanUnsupportedDesc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.5,
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
}

/// 扫描结果面板上的一个动作（加入联络人 / 转帐 / 复制）。
class _SheetAction {
  const _SheetAction({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

/// 取景遮罩：取景框以外压暗，并在框线上加一圈强调色。
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth * 0.68).clamp(180.0, 300.0);
        final radius = Radius.circular(side * 0.09);
        final hole = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            ),
            width: side,
            height: side,
          ),
          radius,
        );
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              painter: _ScrimPainter(
                hole: hole,
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
            Center(
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(radius),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 以 evenOdd 填色画出「整片半透明 + 中央挖空」的遮罩。
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.color});

  final RRect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.color != color;
}

/// 相机初始化失败（多为权限被拒）时的说明画面。
class _ScanErrorView extends StatelessWidget {
  const _ScanErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: const Color(0xFF0B0D14),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withValues(alpha: 0.16),
            ),
            child: Icon(
              denied
                  ? Icons.no_photography_rounded
                  : Icons.videocam_off_rounded,
              color: AppColors.warning,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            denied ? s.scanPermissionTitle : s.scanCameraError,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (denied) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              s.scanPermissionDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(s.back),
          ),
        ],
      ),
    );
  }
}
