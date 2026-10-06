import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// 原生平台：优先存进系统相簿，失败再退回写入档案。
///
/// [gal] 支援 Android / iOS / macOS / Windows；Linux 没有官方实作，
/// 呼叫会抛出例外 —— 这里一律接住并退回写档，因此所有平台都有一条可用路径。
Future<({bool toGallery, String? path})?> saveImageBytesImpl(
  Uint8List bytes,
  String fileName,
) async {
  // 1) 系统相簿：使用者在「照片 / 相簿」App 里就能直接看到。
  try {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImageBytes(bytes);
    return (toGallery: true, path: null);
  } catch (_) {
    // 权限被拒、平台不支援（Linux）、空间不足…… 交给下面的写档路径。
  }

  // 2) 写入档案：依序尝试「下载目录 → 外部储存 → 应用程式文件目录」。
  //    - Windows / macOS / Linux：getDownloadsDirectory() 可用；
  //    - Android：其次 app 专属外部目录（可用档案管理器或 USB 存取）；
  //    - iOS：前两者都回传 null，落到 app 文件目录（可经「档案」App 存取）。
  try {
    Directory? dir = await getDownloadsDirectory();
    dir ??= await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsBytes(bytes, flush: true);
    return (toGallery: false, path: target.path);
  } catch (_) {
    return null;
  }
}
