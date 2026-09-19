import 'package:meta/meta.dart' show immutable;

/// Waku 網路上傳遞的最小單位（對應 nwaku 的 WakuMessage）。
@immutable
class WakuMessage {
  const WakuMessage({
    required this.contentTopic,
    required this.payloadBase64,
    required this.timestampNs,
    this.ephemeral = false,
    this.version = 1,
  });

  /// 例：`/nexuschat/1/dm-xxxxxxxx/json`
  final String contentTopic;

  /// Base64 編碼的 payload。
  final String payloadBase64;

  /// 奈秒時間戳（Waku 協定使用 nanoseconds since epoch）。
  final int timestampNs;

  final bool ephemeral;

  final int version;

  factory WakuMessage.fromJson(Map<dynamic, dynamic> json) {
    final ts = json['timestamp'];
    return WakuMessage(
      contentTopic: (json['contentTopic'] ?? '') as String,
      payloadBase64: (json['payload'] ?? '') as String,
      timestampNs: ts is int ? ts : int.tryParse('$ts') ?? 0,
      ephemeral: (json['ephemeral'] ?? false) as bool,
      version: (json['version'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'payload': payloadBase64,
        'contentTopic': contentTopic,
        'version': version,
        'timestamp': timestampNs,
        'ephemeral': ephemeral,
      };

  /// 以毫秒時間戳建立。
  factory WakuMessage.fromMillis({
    required String contentTopic,
    required String payloadBase64,
    required int timestampMs,
    bool ephemeral = false,
  }) {
    return WakuMessage(
      contentTopic: contentTopic,
      payloadBase64: payloadBase64,
      timestampNs: timestampMs * 1000000,
      ephemeral: ephemeral,
    );
  }

  int get timestampMs => timestampNs ~/ 1000000;
}
