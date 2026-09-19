import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 將圖片壓縮到適合透過 Waku 傳送的大小。
///
/// 流程：先將最長邊縮放到 [maxDim]，再以 JPEG [quality] 重新編碼；
/// 若仍超過 [maxBytes]，逐步降質、必要時再縮一次尺寸。所有平台（含 Web）
/// 都走這條路徑，行為一致。
Uint8List compressImage(
  Uint8List bytes, {
  int maxDim = 1280,
  int quality = 82,
  int maxBytes = 480 * 1024,
}) {
  var decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes; // 無法解碼就原樣送出，由呼叫端做大小檢查

  final longest = decoded.width >= decoded.height ? decoded.width : decoded.height;
  if (longest > maxDim) {
    final scale = maxDim / longest;
    decoded = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
    );
  }

  var q = quality;
  var out = img.encodeJpg(decoded, quality: q);
  while (out.length > maxBytes && q > 30) {
    q -= 12;
    out = img.encodeJpg(decoded, quality: q);
  }
  if (out.length > maxBytes &&
      (decoded.width > 720 || decoded.height > 720)) {
    decoded = img.copyResize(decoded, width: 720);
    out = img.encodeJpg(decoded, quality: q);
  }
  return Uint8List.fromList(out);
}
