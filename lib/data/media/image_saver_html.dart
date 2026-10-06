import 'dart:html' as html;
import 'dart:typed_data';

/// Web：建立 Blob URL 并以 `<a download>` 触发浏览器下载。
///
/// 浏览器会把它交给使用者的下载管理员，行为与一般网页下载一致。
Future<({bool toGallery, String? path})?> saveImageBytesImpl(
  Uint8List bytes,
  String fileName,
) async {
  try {
    final blob = html.Blob(<Object>[bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return (toGallery: false, path: fileName);
  } catch (_) {
    return null;
  }
}
