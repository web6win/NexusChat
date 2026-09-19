import 'dart:html' as html;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Web 平台：把 bytes 包成 Blob 再取 object URL（audioplayers Web 僅支援 UrlSource）。
Future<Source> createAudioSourceImpl(Uint8List bytes, String mimeType) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  return UrlSource(url);
}
