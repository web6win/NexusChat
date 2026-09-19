import 'dart:html' as html;
import 'dart:typed_data';

/// Web 平台：[record] 套件停止錄音後回傳的是 blob URL，需用 fetch 取回
/// ArrayBuffer 才能拿到原始位元組。
Future<Uint8List> readRecordedBytesImpl(String path) async {
  final resp =
      await html.HttpRequest.request(path, responseType: 'arraybuffer');
  final buffer = resp.response as ByteBuffer;
  return buffer.asUint8List();
}
