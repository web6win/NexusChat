import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// 原生平台：優先存進系統相簿，失敗再退回寫入檔案。
///
/// [gal] 支援 Android / iOS / macOS / Windows；Linux 沒有官方實作，
/// 呼叫會拋出例外 —— 這裡一律接住並退回寫檔，因此所有平台都有一條可用路徑。
Future<({bool toGallery, String? path})?> saveImageBytesImpl(
  Uint8List bytes,
  String fileName,
) async {
  // 1) 系統相簿：使用者在「照片 / 相簿」App 裡就能直接看到。
  try {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImageBytes(bytes);
    return (toGallery: true, path: null);
  } catch (_) {
    // 權限被拒、平台不支援（Linux）、空間不足…… 交給下面的寫檔路徑。
  }

  // 2) 寫入檔案：依序嘗試「下載目錄 → 外部儲存 → 應用程式文件目錄」。
  //    - Windows / macOS / Linux：getDownloadsDirectory() 可用；
  //    - Android：其次 app 專屬外部目錄（可用檔案管理器或 USB 存取）；
  //    - iOS：前兩者都回傳 null，落到 app 文件目錄（可經「檔案」App 存取）。
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
