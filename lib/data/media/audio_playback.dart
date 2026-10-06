import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'audio_playback_io.dart'
    if (dart.library.html) 'audio_playback_html.dart';

/// 由录音位元组建立 [AudioPlayer] 可播放的来源。
///
/// 原生平台直接吃 bytes；Web 要把 bytes 包成 Blob 再给 object URL
/// （audioplayers 在 Web 上只接受 [UrlSource]）。
Future<Source> createAudioSource(Uint8List bytes, String mimeType) =>
    createAudioSourceImpl(bytes, mimeType);
