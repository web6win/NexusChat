import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 將圖片壓縮到適合透過 Waku 傳送的大小。
///
/// 流程：先將最長邊縮放到 [maxDim]，再以 JPEG [quality] 重新編碼；
/// 仍超過 [maxBytes] 就先一路降質，品質到底還不夠再逐步縮尺寸，直到落在
/// 預算內為止。所有平台（含 Web）都走這條路徑，行為一致。
///
/// 「縮到能送為止」是刻意的選擇 —— 一張畫質很好卻注定被節點拒收的圖，
/// 對使用者來說等於「傳送失敗」，遠不如畫質差一點但真的送到對方手上。
///
/// 回傳 `null` 表示輸入不是本 App 能解碼的圖片（例如 iPhone 相簿常見的
/// HEIC/HEIF）。這種情況**絕不能原樣送出**：接收端同樣解不開，訊息氣泡會
/// 因為沒有可顯示的圖而塌成一個小點 —— 使用者只會看到「破圖」。
///
/// [maxBytes] 是「壓縮後的原始位元組」，不是送上 Waku 的大小；後者還會
/// 因為兩次 base64 再膨脹約 2.4 倍。預設 256KB（→ 載荷約 610KB）是為了讓
/// 成品落在節點的單則上限之內，只求「畫質最好」反而會整張送不出去。
Uint8List? compressImage(
  Uint8List bytes, {
  int maxDim = 1280,
  int quality = 82,
  int maxBytes = 256 * 1024,
}) {
  final source = img.decodeImage(bytes);
  if (source == null) return null;
  // 顯式宣告成不可為 null 的 Image：下面會在迴圈裡重新指派 decoded，
  // 若沿用 decodeImage 的 Image? 型別，Dart 會在迴圈的合流點取消型別
  // 提升（promotion），decoded.width 就會被視為「可能為 null」。
  img.Image decoded = source;

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
  // 品質降到底還是不夠，就逐步縮尺寸（每次 75%）直到符合預算。
  // 舊版只縮一次到 720 寬，遇到小尺寸但極度瑣碎的圖（例如螢幕截圖）
  // 仍會回傳超出預算的結果，最後在送出時才失敗。
  // [decoded] 每輪都真的縮小，因此尺寸條件會逐輪逼近、必定收斂；
  // 上限 8 輪只是額外保險，避免任何意外造成無窮迴圈。
  var shrinkRounds = 0;
  while (out.length > maxBytes &&
      decoded.width > 360 &&
      decoded.height > 360 &&
      shrinkRounds < 8) {
    shrinkRounds++;
    // 只給 width：height 會依比例自動算出，不會把圖片拉歪。
    decoded = img.copyResize(decoded, width: (decoded.width * 0.75).round());
    out = img.encodeJpg(decoded, quality: q);
  }
  return Uint8List.fromList(out);
}
