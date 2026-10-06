import 'package:meta/meta.dart' show immutable;

import 'nwaku_rest_transport.dart';

/// 单一节点的探测结果（设定页显示用）。
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

  /// 可显示的补充说明（节点版本或错误讯息）。
  final String? detail;

  /// 节点是否已入网（relay 可转发讯息）。
  ///
  /// REST 可达不代表可用：没连上 peer 的节点照样回 200，但讯息送不出去，
  /// 因此设定页必须把「可连线但无 peer」另外标示出来。
  final bool relayReady;
}

/// 节点探测器：对设定清单中的每一台节点各发一次健康检查。
///
/// NexusChat 实际只连线使用者选取的那一台节点（见 `Core.applyTransport`），
/// 但设定页需要在切换前就看出哪一台可用，所以探测刻意独立于连线之外：
/// 这里只读 `/health`，不发布、不订阅，也不影响目前使用中的连线。
///
/// 用完务必呼叫 [dispose] 释放暂时建立的 HTTP 连线。
class NodeProbe {
  NodeProbe(List<String> nodeUrls)
      : nodeUrls = List<String>.unmodifiable(nodeUrls),
        _nodes = <NwakuRestTransport>[
          for (final url in nodeUrls) NwakuRestTransport(baseUrl: url),
        ];

  /// 要探测的节点位址（依设定顺序）。
  final List<String> nodeUrls;

  final List<NwakuRestTransport> _nodes;

  /// 探测所有节点，回传每一台的状态（顺序与 [nodeUrls] 相同）。
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
