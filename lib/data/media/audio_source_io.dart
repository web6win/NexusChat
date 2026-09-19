import 'dart:io';
import 'dart:typed_data';

/// 原生平台：直接讀取檔案系統上的錄音檔。
Future<Uint8List> readRecordedBytesImpl(String path) =>
    File(path).readAsBytes();
