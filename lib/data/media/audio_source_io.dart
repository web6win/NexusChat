import 'dart:io';
import 'dart:typed_data';

/// 原生平台：直接读取档案系统上的录音档。
Future<Uint8List> readRecordedBytesImpl(String path) =>
    File(path).readAsBytes();
