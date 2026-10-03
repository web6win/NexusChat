/// 媒體在 Waku 上的**實際**體積模型。
///
/// 一則圖片 / 語音訊息從「原始位元組」到「送上網路的 payload」會被層層包裝，
/// 每一層都變大：
///
/// ```text
/// media bytes
///   → base64（×4/3）放進 MessageContent 的 JSON
///   → AES-GCM 加密（密文長度不變，但會多出 MAC）
///   → ct 再 base64（×4/3）放進 EncryptedBlob 的 JSON
///   → 加上信封欄位（v / id / type / from / to / ts / pub / sig）
///   → 整個信封 JSON 再 base64（×4/3）成為 Waku payload
/// ```
///
/// 總膨脹約 **2.37 倍**。因此「媒體最多能多大」必須從**網路那端的預算**反推，
/// 直接給一個原始位元組數字（舊版是 700KB）看似合理，實際會讓成品遠超節點
/// 上限 —— 表現就是「大圖永遠傳送失敗」。
///
/// 實測基準（2026-10）：
/// - 原始約 200KB（payload ≈ 486KB）→ 送得出去
/// - 原始約 400KB（payload ≈ 971KB）→ 被節點拒絕
library;

/// 節點單則訊息的 payload 預算（位元組）。
///
/// 已知 486KB 可行、971KB 會被拒，這裡抓 400KB 留下約 18% 餘裕。
/// 若日後換節點或確認上限更高，只需調整這一個數字，其餘全部自動跟著走。
const int kMaxWakuPayloadBytes = 400 * 1024;

/// MessageContent JSON 的欄位開銷（t / text / b64 / mime / name）。
const int _contentJsonOverhead = 96;

/// EncryptedBlob JSON 的欄位開銷（ct / mac / nonce / eph 的鍵與其他值）。
const int _blobJsonOverhead = 140;

/// 信封欄位開銷（v / id / type / from / to / ts / body / pub / sig）。
const int _envelopeJsonOverhead = 512;

int _b64Chars(int bytes) => 4 * ((bytes + 2) ~/ 3);
int _b64Bytes(int chars) => chars * 3 ~/ 4;

/// 估算「原始媒體位元組」送上 Waku 後實際佔多少 payload。
int estimateWakuPayload(int mediaBytes) {
  final content = _b64Chars(mediaBytes) + _contentJsonOverhead;
  final blob = _b64Chars(content) + _blobJsonOverhead;
  final envelope = blob + _envelopeJsonOverhead;
  return _b64Chars(envelope);
}

/// 反推：在給定 payload 預算下，媒體最多能有多少原始位元組。
int maxMediaBytesForPayload([int payloadBudget = kMaxWakuPayloadBytes]) {
  final envelope = _b64Bytes(payloadBudget);
  final blob = envelope - _envelopeJsonOverhead;
  final content = _b64Bytes(blob - _blobJsonOverhead);
  final media = _b64Bytes(content - _contentJsonOverhead);
  return media < 1024 ? 1024 : media;
}

/// 送出前的**硬上限**：超過就直接標記失敗，避免白等一趟還拿到莫名錯誤。
final int kMaxMediaBytes = maxMediaBytesForPayload();

/// 壓縮器的目標：硬上限的 88%，替檔名、說明文字（caption）與估算誤差留空間。
final int kImageTargetBytes = kMaxMediaBytes * 88 ~/ 100;
