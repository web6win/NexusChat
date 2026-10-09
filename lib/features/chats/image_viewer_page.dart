import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../data/media/image_saver.dart';
import '../../shared/feedback.dart';

/// 图片检视页：全萤幕显示，可缩放 / 拖曳，并可下载到装置。
///
/// - 行动装置：双指捏合缩放、单指拖曳（由 [InteractiveViewer] 提供）；
/// - 桌面：没有捏合手势，因此另外提供放大 / 缩小 / 还原按钮；
/// - 下载：Web 触发浏览器下载，原生写入下载目录（见 [saveImageBytes]）。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    required this.bytes,
    required this.fileName,
    super.key,
  });

  final Uint8List bytes;

  /// 下载时使用的档名（已由 [_safeFileName] 处理过）。
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

  /// 以检视区中心为基准缩放（给桌面按钮用；行动装置直接捏合即可）。
  void _zoomBy(double factor) {
    final value = _transform.value;
    final current = value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale);
    final delta = next / current;
    if ((delta - 1).abs() < 0.001) return;

    final size = MediaQuery.sizeOf(context);
    // 把中心移到原点 → 缩放 → 移回去，画面才不会往左上角跑。
    final aboutCenter = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0.0, 1.0)
      ..scaleByDouble(delta, delta, 1.0, 1.0)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0.0, 1.0);
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
    // 进了系统相簿要去「照片 / 相簿」App 找；写档则提示放在哪里。
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
                  // 先完整显示整张图，放大后才交给 InteractiveViewer 拖曳。
                  fit: BoxFit.contain,
                  child: Image.memory(widget.bytes),
                ),
              ),
            ),
          ),
          // 桌面没有捏合手势，给一组明确的缩放控制。
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

/// 产生安全的下载档名：去掉路径分隔符与 Windows 保留字元，并补上副档名。
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
