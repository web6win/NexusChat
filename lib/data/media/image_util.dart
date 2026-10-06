import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'media_size.dart';

/// 将图片压缩到适合透过 Waku 传送的大小。
///
/// 流程：先将最长边缩放到 [maxDim]，再以 JPEG [quality] 重新编码；
/// 仍超过 [maxBytes] 就先一路降质，品质到底还不够再逐步缩尺寸，直到落在
/// 预算内为止。所有平台（含 Web）都走这条路径，行为一致。
///
/// 「缩到能送为止」是刻意的选择 —— 一张画质很好却注定被节点拒收的图，
/// 对使用者来说等于「传送失败」，远不如画质差一点但真的送到对方手上。
///
/// 回传 `null` 表示输入不是本 App 能解码的图片（例如 iPhone 相簿常见的
/// HEIC/HEIF）。这种情况**绝不能原样送出**：接收端同样解不开，讯息气泡会
/// 因为没有可显示的图而塌成一个小点 —— 使用者只会看到「破图」。
///
/// [maxBytes] 是「压缩后的原始位元组」，不是送上 Waku 的大小 —— 后者还会
/// 因为两次 base64 膨胀约 2.37 倍（见 [estimateWakuPayload]）。预设值由
/// 网路端的 payload 预算反推（[kImageTargetBytes]），只求「画质最好」反而
/// 会让整张图送不出去。
Uint8List? compressImage(
  Uint8List bytes, {
  int maxDim = 1280,
  int quality = 82,
  int? maxBytes,
}) {
  // 不能写成预设值：kImageTargetBytes 是执行期算出来的（由 payload 预算
  // 反推），而 Dart 要求可选参数的预设值必须是编译期常数。
  final budget = maxBytes ?? kImageTargetBytes;
  final source = img.decodeImage(bytes);
  if (source == null) return null;
  // 显式宣告成不可为 null 的 Image：下面会在回圈里重新指派 decoded，
  // 若沿用 decodeImage 的 Image? 型别，Dart 会在回圈的合流点取消型别
  // 提升（promotion），decoded.width 就会被视为「可能为 null」。
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
  while (out.length > budget && q > 30) {
    q -= 12;
    out = img.encodeJpg(decoded, quality: q);
  }
  // 品质降到底还是不够，就逐步缩尺寸（每次 75%）直到符合预算。
  // 旧版只缩一次到 720 宽，遇到小尺寸但极度琐碎的图（例如萤幕截图）
  // 仍会回传超出预算的结果，最后在送出时才失败。
  // [decoded] 每轮都真的缩小，因此尺寸条件会逐轮逼近、必定收敛；
  // 上限 8 轮只是额外保险，避免任何意外造成无穷回圈。
  var shrinkRounds = 0;
  while (out.length > budget &&
      decoded.width > 360 &&
      decoded.height > 360 &&
      shrinkRounds < 8) {
    shrinkRounds++;
    // 只给 width：height 会依比例自动算出，不会把图片拉歪。
    decoded = img.copyResize(decoded, width: (decoded.width * 0.75).round());
    out = img.encodeJpg(decoded, quality: q);
  }
  return Uint8List.fromList(out);
}
