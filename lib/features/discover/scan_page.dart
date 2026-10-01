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

/// 掃一掃：以相機讀取 QR Code。
///
/// 結果處理規則（依序判斷）：
/// 1. 付款請求（`ethereum:0x…?value=…` / `tron:T…?amount=…`）→ 可直接轉帳。
/// 2. DID / 0x 地址 / ENS 名稱 → 加入聯絡人、轉帳或複製。
/// 3. 網址（`http(s)://…` 或以網域開頭的字串）→ 直接以外部瀏覽器開啟。
/// 4. 其他文字 → 顯示內容並可複製。
///
/// 相機後端由 mobile_scanner 提供，僅支援 Android / iOS / macOS / 瀏覽器；
/// 其餘平台（Windows、Linux）改為顯示不支援提示，而不是讓畫面壞掉。
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({this.pickAddress = false, this.chain, super.key});

  /// 挑選模式：只把「收款地址 / 付款請求」回傳給上一頁（轉帳頁用），
  /// 不做加入聯絡人等其他動作。
  final bool pickAddress;

  /// 期望的鏈；掃到的內容若明顯屬於別條鏈，仍會回傳，由轉帳頁提示並切換。
  final ChainType? chain;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  MobileScannerController? _controller;

  /// 是否正在處理某個掃描結果。處理期間停止辨識，避免同一個碼反覆觸發。
  bool _busy = false;

  /// 目前平台是否有可用的相機後端。
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
        // 只認 QR Code：這個頁面不會掃商品條碼，限定格式可減少誤判。
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        // 同一個碼只回報一次，使用者不必擔心鏡頭晃一下就連續觸發。
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
    // 挑選模式（轉帳頁呼叫）：只收「可以當收款對象」的內容。
    if (widget.pickAddress) {
      await _pickAddress(value);
      return;
    }
    // 付款請求優先：`ethereum:0x…?value=…` 同時帶地址與金額，比純地址明確。
    final payment = PaymentUri.parse(value);
    if (payment != null) {
      await _showPaymentSheet(payment, value);
      return;
    }
    // 身份類內容優先於網址判斷，否則 `name.eth` 會被當成一般網域開出去。
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

  /// 挑選模式：把掃到的內容原樣回傳，由轉帳頁解析地址 / 金額 / 鏈。
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

  /// 帶著掃到的內容前往轉帳頁。
  Future<void> _openSend(String value) async {
    final router = GoRouter.of(context);
    // DID 對轉帳沒有意義，換成地址；ENS 需要線上解析，維持原樣讓使用者處理。
    final target = Did.isEthrDid(value) ? Did.toAddress(value) : value;
    final chain = _sendChainFor(target);
    final query = Uri(queryParameters: <String, String>{
      'address': target,
      // 只有能確定時才指定鏈；0x 地址在以太坊與 Besu 都合法，交給使用者
      // 目前的選擇，不要在背後偷偷換網路。
      if (chain != null) 'chain': chain.id,
    }).query;
    // push 而非 go：保留返回堆疊，轉帳頁才不會變成沒有上一頁的孤島。
    router.push('/send?$query');
  }

  /// 掃到的內容屬於哪一條鏈；不確定時回傳 null（沿用設定）。
  ChainType? _sendChainFor(String value) {
    // 帶 scheme 的付款請求已經寫明是哪條鏈。
    final uri = PaymentUri.parse(value);
    if (uri != null) return uri.chain;
    final bare = PaymentUri.fromAddress(value);
    if (bare == null) return null;
    // T 開頭只可能是 TRON；0x 則可能是任一條 EVM 鏈。
    return bare.chain == ChainType.tron ? ChainType.tron : null;
  }

  /// 掃到網址：直接以外部瀏覽器開啟；成功就關閉掃碼頁，失敗則回到掃描狀態。
  Future<void> _openLink(Uri uri) async {
    final router = GoRouter.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      _exit(router);
      return;
    }
    showAppSnack(context, context.s.scanOpenFailed, danger: true);
    await _resume();
  }

  /// 掃到 NexusChat 身份（DID / 地址 / ENS）：加入聯絡人、轉帳或複製。
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

  /// 掃到付款請求（帶 scheme 的支付 URI）：顯示鏈別與金額，可直接轉帳。
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

  /// 掃到其他文字：單純顯示內容並可複製。
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

  /// 共用的掃描結果面板。回傳動作的 id，取消則回傳 null。
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
                // 第一個動作是主要動作（實心），其餘為次要（描邊）。
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

  /// 加入聯絡人後直接開啟對話；加入失敗則留在掃描頁並提示原因。
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

    // 先把 DID 解析出來（ENS 要靠剛寫入的聯絡人回查），再離開頁面。
    final did = _resolveDid(value);
    showAppSnack(context, context.s.contactsAdded);
    if (did != null) {
      // go 會直接換掉整個堆疊，掃碼頁也一併收掉。
      router.go('/chats?peer=${Uri.encodeComponent(did)}');
    } else {
      _exit(router);
    }
  }

  /// 離開掃碼頁：能 pop 就 pop，否則退回發現頁（例如由深層連結直接進入）。
  ///
  /// 這裡用捕獲的 [router] 而非 `context`：呼叫當下頁面可能已經開始銷毀。
  void _exit(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/discover');
    }
  }

  void _close() => _exit(GoRouter.of(context));

  /// 解析掃描到的身份字串對應的 DID；ENS 需先加入聯絡人才能從狀態回查。
  String? _resolveDid(String value) {
    if (Did.isEthrDid(value)) return value.toLowerCase();
    if (Did.isAddress(value)) return Did.fromAddress(value);
    final target = value.toLowerCase();
    for (final contact in ref.read(contactsProvider)) {
      if (contact.ens?.toLowerCase() == target) return contact.did;
    }
    return null;
  }

  /// 處理完（或使用者取消）後恢復掃描。
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

  /// 允許的網域：`example.com`、`sub.example.co.uk:8080/path?q=1`。
  /// 頂級域限定為 2 個以上的英文字母，避免把 `1.5` 這類純數字誤判成網址。
  static final RegExp _domainPattern = RegExp(
    r'^[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*'
    r'\.[a-zA-Z]{2,}(?::\d{1,5})?(?:[/?#]\S*)?$',
  );

  /// 把掃描到的字串轉成可開啟的 http(s) 網址；不是網址則回傳 null。
  static Uri? _asHttpUri(String value) {
    final text = value.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;

    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      return (uri != null && uri.host.isNotEmpty) ? uri : null;
    }

    // 沒有 scheme 的裸網域也視為網址，補上 https。
    if (_domainPattern.hasMatch(text)) return Uri.tryParse('https://$text');
    return null;
  }

  Future<void> _switchCamera() async {
    try {
      await _controller?.switchCamera();
    } catch (_) {
      // 只有單一鏡頭的裝置會失敗；維持目前鏡頭即可，不需要打擾使用者。
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

/// 掃描結果面板上的一個動作（加入聯絡人 / 轉帳 / 複製）。
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

/// 取景遮罩：取景框以外壓暗，並在框線上加一圈強調色。
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

/// 以 evenOdd 填色畫出「整片半透明 + 中央挖空」的遮罩。
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

/// 相機初始化失敗（多為權限被拒）時的說明畫面。
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
