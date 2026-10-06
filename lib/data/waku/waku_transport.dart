import 'package:meta/meta.dart' show immutable;

import 'waku_message.dart';

/// 传输实作类型。
enum TransportKind {
  /// 透过 nwaku 的 REST 介面（relay / store / filter）。
  nwakuRest('nwaku-rest');

  const TransportKind(this.value);

  final String value;

  /// 由持久化的字串还原。
  ///
  /// 未知值（包含已移除的 `loopback`）一律回传 [TransportKind.nwakuRest]，
  /// 让旧安装自动升级到真实节点，而不是卡在无法通讯的模式。
  static TransportKind fromValue(String? value) {
    for (final k in TransportKind.values) {
      if (k.value == value) return k;
    }
    return TransportKind.nwakuRest;
  }
}

/// 节点的健康检查结果。
@immutable
class TransportHealth {
  const TransportHealth({
    required this.ok,
    this.detail,
    this.latencyMs,
    this.relayReady = true,
  });

  final bool ok;

  /// 可显示的说明文字（例如错误讯息或节点版本）。
  final String? detail;

  final int? latencyMs;

  /// 节点的 relay 是否真的能转发讯息。
  ///
  /// REST 介面可达（HTTP 200）**不代表**节点能收发讯息：若节点没连上任何
  /// peer，`/health` 会回 `connectionStatus: Disconnected`、Relay 为
  /// `NOT_READY`，此时发布仍回 200 但讯息根本不会被转发。上层需要区分
  /// 「连得上但没入网」与「真的可用」，否则会显示「已连线」却收不到讯息。
  final bool relayReady;

  static const unknown = TransportHealth(ok: false, detail: null);
}

/// Waku 传输层抽象：让上层不必关心背后是真节点还是本机模拟。
abstract class WakuTransport {
  TransportKind get kind;

  /// 是否已经启动。
  bool get isRunning;

  Future<void> start();

  Future<void> stop();

  /// 释放底层资源（HTTP 连线池等）。预设不需要特别处理。
  void dispose() {}

  /// 发布一则讯息到 relay（并可供 store 节点保存）。
  Future<void> publish(WakuMessage message);

  /// 订阅即时推播（Waku filter v2）：节点会把符合这些 content topic 的
  /// 讯息主动收集起来，客户端再用 [query] 取走，达到「即时」而非纯轮询。
  ///
  /// 节点不支援时应静默忽略，上层仍会退回一般轮询。
  Future<void> subscribe(List<String> contentTopics) async {}

  /// 依 content topic 拉取讯息；[sinceMs] 为毫秒时间戳。
  Future<List<WakuMessage>> query({
    required List<String> contentTopics,
    int? sinceMs,
    int limit = 100,
  });

  Future<TransportHealth> health();
}
