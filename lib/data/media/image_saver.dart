import 'dart:typed_data';

import 'image_saver_io.dart' if (dart.library.html) 'image_saver_html.dart';

/// 把图片的原始位元组存到使用者的装置。
///
/// - Android / iOS / macOS / Windows：优先用 [gal] 存进**系统相簿**；
/// - Web：以 `<a download>` 触发浏览器下载；
/// - 其它情况（Linux、权限被拒、相簿 API 失败）：退回写入档案。
///
/// 回传 `null` 代表完全失败；否则 `toGallery` 表示进了系统相簿，
/// 非相簿时 `path` 会是实际写入的路径。
Future<({bool toGallery, String? path})?> saveImageBytes(
  Uint8List bytes,
  String fileName,
) =>
    saveImageBytesImpl(bytes, fileName);
