import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// 原生平台：直接用 bytes 播放，并带上 MIME 让平台播放器知道格式。
Future<Source> createAudioSourceImpl(Uint8List bytes, String mimeType) async =>
    BytesSource(bytes, mimeType: mimeType);
