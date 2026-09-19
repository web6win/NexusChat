import 'dart:typed_data';

import 'audio_source_io.dart'
    if (dart.library.html) 'audio_source_html.dart';

/// 讀取錄音檔的原始位元組。
///
/// 原生平台直接讀檔案；Web 上 [record] 回傳的是 blob URL，要改用
/// `fetch` 取回 ArrayBuffer。
Future<Uint8List> readRecordedBytes(String path) =>
    readRecordedBytesImpl(path);
