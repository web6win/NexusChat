import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../data/media/image_saver.dart';
import '../../shared/feedback.dart';

/// 圖片檢視頁：全螢幕顯示，可縮放 / 拖曳，並可下載到裝置。
///
/// - 行動裝置：雙指捏合縮放、單指拖曳（由 [InteractiveViewer] 提供）；
/// - 桌面：沒有捏合手勢，因此另外提供放大 / 縮小 / 還原按鈕；
/// - 下載：Web 觸發瀏覽器下載，原生寫入下載目錄（見 [saveImageBytes]）。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    required this.bytes,
    required this.fileName,
    super.key,
  });

  final Uint8List bytes;

  /// 下載時使用的檔名（已由 [_safeFileName] 處理過）。
  final String fileName;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  static const double _minScale = 0.5;
  static const double _maxScale = 8;

  final TransformationController _transform = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// 以檢視區中心為基準縮放（給桌面按鈕用；行動裝置直接捏合即可）。
  void _zoomBy(double factor) {
    final value = _transform.value;
    final current = value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale);
    final delta = next / current;
    if ((delta - 1).abs() < 0.001) return;

    final size = MediaQuery.sizeOf(context);
    // 把中心移到原點 → 縮放 → 移回去，畫面才不會往左上角跑。
    final aboutCenter = Matrix4.identity()
      ..translate(size.width / 2, size.height / 2)
      ..scale(delta)
      ..translate(-size.width / 2, -size.height / 2);
    _transform.value = aboutCenter * value;
    setState(() {});
  }

  void _reset() {
    _transform.value = Matrix4.identity();
    setState(() {});
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await saveImageBytes(widget.bytes, widget.fileName);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      showAppSnack(context, context.s.chatImageSaveFailed, danger: true);
      return;
    }
    // 進了系統相簿要去「照片 / 相簿」App 找；寫檔則提示放在哪裡。
    showAppSnack(
      context,
      result.toGallery
          ? context.s.chatImageSavedToAlbum
          : context.s.chatImageSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scale = _transform.value.getMaxScaleOnAxis();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: s.chatImageDownload,
            onPressed: _saving ? null : _download,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              child: SizedBox.expand(
                child: FittedBox(
                  // 先完整顯示整張圖，放大後才交給 InteractiveViewer 拖曳。
                  fit: BoxFit.contain,
                  child: Image.memory(widget.bytes),
                ),
              ),
            ),
          ),
          // 桌面沒有捏合手勢，給一組明確的縮放控制。
          SafeArea(
            top: false,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    tooltip: s.chatImageZoomOut,
                    color: Colors.white,
                    onPressed: scale <= _minScale ? null : () => _zoomBy(1 / 1.5),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${(scale * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.chatImageZoomIn,
                    color: Colors.white,
                    onPressed: scale >= _maxScale ? null : () => _zoomBy(1.5),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.fit_screen_rounded, size: 18),
                    label: Text(s.chatImageReset),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 產生安全的下載檔名：去掉路徑分隔符與 Windows 保留字元，並補上副檔名。
String imageFileNameFor(String? rawName, int timestampMs) {
  final base = (rawName == null || rawName.trim().isEmpty)
      ? 'nexuschat-$timestampMs'
      : rawName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final lower = base.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp')) {
    return base;
  }
  return '$base.jpg';
}
