import 'package:meta/meta.dart' show immutable;

import 'waku_message.dart';

/// 傳輸實作類型。
enum TransportKind {
  /// 透過 nwaku 的 REST 介面（relay / store / filter）。
  nwakuRest('nwaku-rest');

  const TransportKind(this.value);

  final String value;

  /// 由持久化的字串還原。
  ///
  /// 未知值（包含已移除的 `loopback`）一律回傳 [TransportKind.nwakuRest]，
  /// 讓舊安裝自動升級到真實節點，而不是卡在無法通訊的模式。
  static TransportKind fromValue(String? value) {
    for (final k in TransportKind.values) {
      if (k.value == value) return k;
    }
    return TransportKind.nwakuRest;
  }
}

/// 節點的健康檢查結果。
@immutable
class TransportHealth {
  const TransportHealth({
    required this.ok,
    this.detail,
    this.latencyMs,
    this.relayReady = true,
  });

  final bool ok;

  /// 可顯示的說明文字（例如錯誤訊息或節點版本）。
  final String? detail;

  final int? latencyMs;

  /// 節點的 relay 是否真的能轉發訊息。
  ///
  /// REST 介面可達（HTTP 200）**不代表**節點能收發訊息：若節點沒連上任何
  /// peer，`/health` 會回 `connectionStatus: Disconnected`、Relay 為
  /// `NOT_READY`，此時發布仍回 200 但訊息根本不會被轉發。上層需要區分
  /// 「連得上但沒入網」與「真的可用」，否則會顯示「已連線」卻收不到訊息。
  final bool relayReady;

  static const unknown = TransportHealth(ok: false, detail: null);
}

/// Waku 傳輸層抽象：讓上層不必關心背後是真節點還是本機模擬。
abstract class WakuTransport {
  TransportKind get kind;

  /// 是否已經啟動。
  bool get isRunning;

  Future<void> start();

  Future<void> stop();

  /// 釋放底層資源（HTTP 連線池等）。預設不需要特別處理。
  void dispose() {}

  /// 發布一則訊息到 relay（並可供 store 節點保存）。
  Future<void> publish(WakuMessage message);

  /// 訂閱即時推播（Waku filter v2）：節點會把符合這些 content topic 的
  /// 訊息主動收集起來，客戶端再用 [query] 取走，達到「即時」而非純輪詢。
  ///
  /// 節點不支援時應靜默忽略，上層仍會退回一般輪詢。
  Future<void> subscribe(List<String> contentTopics) async {}

  /// 依 content topic 拉取訊息；[sinceMs] 為毫秒時間戳。
  Future<List<WakuMessage>> query({
    required List<String> contentTopics,
    int? sinceMs,
    int limit = 100,
  });

  Future<TransportHealth> health();
}
