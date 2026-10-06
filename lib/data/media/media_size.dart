/// 媒体在 Waku 上的**实际**体积模型。
///
/// 一则图片 / 语音讯息从「原始位元组」到「送上网路的 payload」会被层层包装，
/// 每一层都变大：
///
/// ```text
/// media bytes
///   → base64（×4/3）放进 MessageContent 的 JSON
///   → AES-GCM 加密（密文长度不变，但会多出 MAC）
///   → ct 再 base64（×4/3）放进 EncryptedBlob 的 JSON
///   → 加上信封栏位（v / id / type / from / to / ts / pub / sig）
///   → 整个信封 JSON 再 base64（×4/3）成为 Waku payload
/// ```
///
/// 总膨胀约 **2.37 倍**。因此「媒体最多能多大」必须从**网路那端的预算**反推，
/// 直接给一个原始位元组数字（旧版是 700KB）看似合理，实际会让成品远超节点
/// 上限 —— 表现就是「大图永远传送失败」。
///
/// 实测基准（2026-10）：
/// - 原始约 200KB（payload ≈ 486KB）→ 送得出去
/// - 原始约 400KB（payload ≈ 971KB）→ 被节点拒绝
library;

/// 节点单则讯息的 payload 预算（位元组）。
///
/// 已知 486KB 可行、971KB 会被拒，这里抓 400KB 留下约 18% 余裕。
/// 若日后换节点或确认上限更高，只需调整这一个数字，其余全部自动跟著走。
const int kMaxWakuPayloadBytes = 400 * 1024;

/// MessageContent JSON 的栏位开销（t / text / b64 / mime / name）。
const int _contentJsonOverhead = 96;

/// EncryptedBlob JSON 的栏位开销（ct / mac / nonce / eph 的键与其他值）。
const int _blobJsonOverhead = 140;

/// 信封栏位开销（v / id / type / from / to / ts / body / pub / sig）。
const int _envelopeJsonOverhead = 512;

int _b64Chars(int bytes) => 4 * ((bytes + 2) ~/ 3);
int _b64Bytes(int chars) => chars * 3 ~/ 4;

/// 估算「原始媒体位元组」送上 Waku 后实际占多少 payload。
int estimateWakuPayload(int mediaBytes) {
  final content = _b64Chars(mediaBytes) + _contentJsonOverhead;
  final blob = _b64Chars(content) + _blobJsonOverhead;
  final envelope = blob + _envelopeJsonOverhead;
  return _b64Chars(envelope);
}

/// 反推：在给定 payload 预算下，媒体最多能有多少原始位元组。
int maxMediaBytesForPayload([int payloadBudget = kMaxWakuPayloadBytes]) {
  final envelope = _b64Bytes(payloadBudget);
  final blob = envelope - _envelopeJsonOverhead;
  final content = _b64Bytes(blob - _blobJsonOverhead);
  final media = _b64Bytes(content - _contentJsonOverhead);
  return media < 1024 ? 1024 : media;
}

/// 送出前的**硬上限**：超过就直接标记失败，避免白等一趟还拿到莫名错误。
final int kMaxMediaBytes = maxMediaBytesForPayload();

/// 压缩器的目标：硬上限的 88%，替档名、说明文字（caption）与估算误差留空间。
final int kImageTargetBytes = kMaxMediaBytes * 88 ~/ 100;
