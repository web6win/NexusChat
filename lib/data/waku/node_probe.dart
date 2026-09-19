import 'package:meta/meta.dart' show immutable;

import 'nwaku_rest_transport.dart';

/// 單一節點的探測結果（設定頁顯示用）。
@immutable
class NodeStatus {
  const NodeStatus({
    required this.url,
    required this.ok,
    this.latencyMs,
    this.detail,
    this.relayReady = true,
  });

  final String url;

  final bool ok;

  final int? latencyMs;

  /// 可顯示的補充說明（節點版本或錯誤訊息）。
  final String? detail;

  /// 節點是否已入網（relay 可轉發訊息）。
  ///
  /// REST 可達不代表可用：沒連上 peer 的節點照樣回 200，但訊息送不出去，
  /// 因此設定頁必須把「可連線但無 peer」另外標示出來。
  final bool relayReady;
}

/// 節點探測器：對設定清單中的每一台節點各發一次健康檢查。
///
/// NexusChat 實際只連線使用者選取的那一台節點（見 `Core.applyTransport`），
/// 但設定頁需要在切換前就看出哪一台可用，所以探測刻意獨立於連線之外：
/// 這裡只讀 `/health`，不發布、不訂閱，也不影響目前使用中的連線。
///
/// 用完務必呼叫 [dispose] 釋放暫時建立的 HTTP 連線。
class NodeProbe {
  NodeProbe(List<String> nodeUrls)
      : nodeUrls = List<String>.unmodifiable(nodeUrls),
        _nodes = <NwakuRestTransport>[
          for (final url in nodeUrls) NwakuRestTransport(baseUrl: url),
        ];

  /// 要探測的節點位址（依設定順序）。
  final List<String> nodeUrls;

  final List<NwakuRestTransport> _nodes;

  /// 探測所有節點，回傳每一台的狀態（順序與 [nodeUrls] 相同）。
  Future<List<NodeStatus>> probeAll() async {
    if (_nodes.isEmpty) return const <NodeStatus>[];
    return Future.wait(
      _nodes.map((node) async {
        final health = await node.health();
        return NodeStatus(
          url: node.baseUrl,
          ok: health.ok,
          latencyMs: health.latencyMs,
          detail: health.detail,
          relayReady: health.relayReady,
        );
      }),
    );
  }

  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
  }
}
