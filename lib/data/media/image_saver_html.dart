import 'dart:html' as html;
import 'dart:typed_data';

/// Web：建立 Blob URL 並以 `<a download>` 觸發瀏覽器下載。
///
/// 瀏覽器會把它交給使用者的下載管理員，行為與一般網頁下載一致。
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
