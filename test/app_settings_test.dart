import 'package:flutter_test/flutter_test.dart';

import 'package:nexuschat/data/models/app_settings.dart';
import 'package:nexuschat/data/models/chain.dart';
import 'package:nexuschat/data/waku/waku_transport.dart';

/// 节点设定与旧版资料迁移的单元测试。
///
/// 这支测试需要 Flutter 绑定，因为 [AppSettings] 依赖 `flutter/material`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('节点连线设定', () {
    test('预设只连线使用中的那一个节点', () {
      const settings = AppSettings();

      expect(settings.activeNodeUrl, AppSettings.defaultActiveNodeUrl);
      expect(
        settings.resolvedActiveNodeUrl,
        AppSettings.defaultActiveNodeUrl,
      );
    });

    test('切换使用中的节点会改变实际连线的节点', () {
      const settings = AppSettings();
      final switched = settings.copyWith(
        activeNodeUrl: 'https://waku02.web6.win',
      );

      expect(switched.resolvedActiveNodeUrl, 'https://waku02.web6.win');
      // 节点清单本身不变：清单只是候选池，不代表会同时连线。
      expect(switched.nodeUrls, AppSettings.builtinNodeUrls);
    });

    test('使用中的节点不在清单时退回第一台', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'activeNodeUrl': 'https://gone.example.com',
        'nodeUrls': <String>['https://waku01.web6.win'],
      });

      expect(settings.activeNodeUrl, 'https://waku01.web6.win');
      expect(settings.resolvedActiveNodeUrl, 'https://waku01.web6.win');
    });
  });

  group('设定持久化', () {
    test('使用中的节点可来回还原', () {
      final saved = AppSettings().copyWith(
        nodeUrls: <String>[
          ...AppSettings.builtinNodeUrls,
          'https://my.node',
        ],
        activeNodeUrl: 'https://my.node',
      );
      final restored = AppSettings.fromJson(saved.toJson());

      expect(restored.activeNodeUrl, 'https://my.node');
      expect(restored.resolvedActiveNodeUrl, 'https://my.node');
      expect(restored.nodeUrls, contains('https://my.node'));
    });

    test('旧版单一 nodeUrl 会并入清单，且没有记录使用中节点时取第一台', () {
      final legacy = AppSettings.fromJson(<String, dynamic>{
        'nodeUrl': 'https://legacy.example.com',
      });

      expect(legacy.nodeUrls, contains('https://legacy.example.com'));
      expect(legacy.activeNodeUrl, AppSettings.defaultActiveNodeUrl);
      expect(legacy.nodeUrls.first, AppSettings.defaultActiveNodeUrl);
    });

    test('旧版 loopback 传输模式会升级为 nwaku REST', () {
      final legacy = AppSettings.fromJson(<String, dynamic>{
        'transport': 'loopback',
      });

      expect(legacy.transport, TransportKind.nwakuRest);
    });

    test('节点位址会正规化：补 scheme、去尾斜线、拒绝无效值', () {
      expect(
        AppSettings.normalizeNodeUrl('waku01.web6.win/'),
        'https://waku01.web6.win',
      );
      expect(
        AppSettings.normalizeNodeUrl('  https://a.example.com//  '),
        'https://a.example.com',
      );
      expect(AppSettings.normalizeNodeUrl(''), '');
      expect(AppSettings.normalizeNodeUrl('not a url'), '');
    });

    test('内建节点判断用于禁止删除', () {
      expect(AppSettings.isBuiltinNode('https://waku01.web6.win'), isTrue);
      expect(AppSettings.isBuiltinNode('https://waku02.web6.win'), isTrue);
      expect(AppSettings.isBuiltinNode('https://my.node'), isFalse);
    });
  });

  group('RPC 端点（多链）', () {
    test('未自订时使用各链的预设端点', () {
      const settings = AppSettings();

      expect(
        settings.rpcFor(ChainType.ethereum),
        ChainConfig.of(ChainType.ethereum).defaultRpc,
      );
      expect(
        settings.rpcFor(ChainType.base),
        ChainConfig.of(ChainType.base).defaultRpc,
      );
      expect(
        settings.rpcFor(ChainType.tron),
        ChainConfig.of(ChainType.tron).defaultRpc,
      );
    });

    test('自订端点只影响对应的链', () {
      final settings = AppSettings().withRpc(ChainType.base, 'https://my.base');

      expect(settings.rpcFor(ChainType.base), 'https://my.base');
      // 其他链不受影响。
      expect(
        settings.rpcFor(ChainType.arbitrum),
        ChainConfig.of(ChainType.arbitrum).defaultRpc,
      );
    });

    test('清空自订值即还原预设端点', () {
      final settings =
          AppSettings().withRpc(ChainType.bsc, 'https://my.bsc');
      final restored = settings.withRpc(ChainType.bsc, '');

      expect(
        restored.rpcFor(ChainType.bsc),
        ChainConfig.of(ChainType.bsc).defaultRpc,
      );
    });

    test('旧版逐链栏位会迁进 rpcOverrides', () {
      final legacy = AppSettings.fromJson(<String, dynamic>{
        'rpcUrl': 'https://legacy.eth',
        'tronRpcUrl': 'https://legacy.tron',
        'besuRpcUrl': 'https://legacy.besu',
      });

      expect(legacy.rpcFor(ChainType.ethereum), 'https://legacy.eth');
      expect(legacy.rpcFor(ChainType.tron), 'https://legacy.tron');
      expect(legacy.rpcFor(ChainType.besu), 'https://legacy.besu');
      // 新链没有旧资料，走预设值。
      expect(
        legacy.rpcFor(ChainType.base),
        ChainConfig.of(ChainType.base).defaultRpc,
      );
    });

    test('端点设定可来回还原', () {
      final saved = AppSettings()
          .withRpc(ChainType.arbitrum, 'https://my.arb')
          .withRpc(ChainType.tron, 'https://my.tron');
      final restored = AppSettings.fromJson(saved.toJson());

      expect(restored.rpcFor(ChainType.arbitrum), 'https://my.arb');
      expect(restored.rpcFor(ChainType.tron), 'https://my.tron');
    });
  });

  group('链别设定', () {
    test('chainId 可用来挡下填错的端点', () {
      expect(ChainConfig.of(ChainType.base).expectedChainId, 8453);
      expect(ChainConfig.of(ChainType.arbitrum).expectedChainId, 42161);
      expect(ChainConfig.of(ChainType.bsc).expectedChainId, 56);

      expect(ChainConfig.of(ChainType.base).isWrongChain(8453), isFalse);
      expect(ChainConfig.of(ChainType.base).isWrongChain(1), isTrue);
      // 没有预期 chainId 的链不做比对。
      expect(ChainConfig.of(ChainType.besu).isWrongChain(1), isFalse);
    });

    test('EVM 链共用 0x 地址，TRON 不是 EVM', () {
      expect(ChainType.base.isEvm, isTrue);
      expect(ChainType.arbitrum.isEvm, isTrue);
      expect(ChainType.bsc.isEvm, isTrue);
      expect(ChainType.tron.isEvm, isFalse);
    });

    test('预设链为 WEB6', () {
      expect(AppSettings.defaultChain, ChainType.besu);
      expect(const AppSettings().chain, ChainType.besu);
      // 从没记录过链别 → 用预设值。
      expect(AppSettings.fromJson(<String, dynamic>{}).chain, ChainType.besu);
      // 已经选过的照旧，不因为预设值改了就被换掉。
      expect(
        AppSettings.fromJson(<String, dynamic>{'chain': 'ethereum'}).chain,
        ChainType.ethereum,
      );
    });

    test('WEB6 原生代币为 Contribution（CNT）', () {
      final config = ChainConfig.of(ChainType.besu);

      expect(config.name, 'Contribution');
      expect(config.symbol, 'CNT');
      // 链上精度 18 位由 TxService.sendEvm 的 ×10^18 决定（EVM wei），
      // 这里的 displayDecimals 只是介面显示位数。
      expect(config.displayDecimals, 6);
    });
  });
}
