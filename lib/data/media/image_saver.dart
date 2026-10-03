import 'dart:typed_data';

import 'image_saver_io.dart' if (dart.library.html) 'image_saver_html.dart';

/// 把圖片的原始位元組存到使用者的裝置。
///
/// - Android / iOS / macOS / Windows：優先用 [gal] 存進**系統相簿**；
/// - Web：以 `<a download>` 觸發瀏覽器下載；
/// - 其它情況（Linux、權限被拒、相簿 API 失敗）：退回寫入檔案。
///
/// 回傳 `null` 代表完全失敗；否則 `toGallery` 表示進了系統相簿，
/// 非相簿時 `path` 會是實際寫入的路徑。
Future<({bool toGallery, String? path})?> saveImageBytes(
  Uint8List bytes,
  String fileName,
) =>
    saveImageBytesImpl(bytes, fileName);
