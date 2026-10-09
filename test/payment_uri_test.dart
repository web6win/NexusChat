import 'package:nexuschat/data/crypto/tron_address.dart';
import 'package:nexuschat/data/ethereum/payment_uri.dart';
import 'package:nexuschat/data/models/chain.dart';
import 'package:test/test.dart';

const String _ethAddress = '0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';

/// 64 位元组的未压缩公钥（hex），用来产生一组合法的 TRON 地址。
final String _tronAddress = TronAddress.fromPublicKeyHex('ab' * 64);

void main() {
  group('PaymentUri', () {
    test('EVM 的 value 以 wei 为单位', () {
      final request = PaymentUri.parse('ethereum:$_ethAddress?value=1e18');
      expect(request, isNotNull);
      expect(request!.chain, ChainType.ethereum);
      expect(request.address, _ethAddress);
      expect(request.amount, 1.0);
    });

    test('含小数点的 value 是人类可读单位', () {
      final request = PaymentUri.parse('ethereum:$_ethAddress?value=0.5');
      expect(request?.amount, 0.5);
    });

    test('整数 value 一律视为 wei（不再靠数量级猜测）', () {
      // 1e18 wei = 1 ETH。
      expect(
        PaymentUri.parse('ethereum:$_ethAddress?value=1000000000000000000')
            ?.amount,
        1.0,
      );
      // 回归保护：旧实作会把 < 1 gwei 的整数当成人类可读单位，
      // 让 `value=5` 被放大 1e18 倍解读成 5 ETH。
      final small = PaymentUri.parse('ethereum:$_ethAddress?value=5');
      expect(small?.amount, isNotNull);
      expect(small!.amount! < 1e-15, isTrue,
          reason: '5 wei 不应被解读成 5 ETH');
    });

    test('无效金额（0 / 负数 / 非数字）不带入金额', () {
      expect(
        PaymentUri.parse('ethereum:$_ethAddress?value=0')?.amount,
        isNull,
      );
      expect(
        PaymentUri.parse('ethereum:$_ethAddress?value=-1')?.amount,
        isNull,
      );
      expect(
        PaymentUri.parse('ethereum:$_ethAddress?value=abc')?.amount,
        isNull,
      );
      // 金额无效不代表整包无效 —— 地址仍要能带入让使用者手动填金额。
      expect(PaymentUri.parse('ethereum:$_ethAddress?value=abc'), isNotNull);
    });

    test('TRON 的 amount 含小数点时是人类可读单位', () {
      expect(
        PaymentUri.parse('tron:$_tronAddress?amount=0.5')?.amount,
        0.5,
      );
    });

    test('EIP-681 的 @chainId 会被读出', () {
      final request =
          PaymentUri.parse('ethereum:$_ethAddress@1?value=0.5');
      expect(request?.requestChainId, 1);
      expect(request?.address, _ethAddress);
      expect(request?.amount, 0.5);
    });

    test('TRON 的 amount 以 sun 为单位', () {
      final request = PaymentUri.parse('tron:$_tronAddress?amount=2000000');
      expect(request, isNotNull);
      expect(request!.chain, ChainType.tron);
      expect(request.address, _tronAddress);
      expect(request.amount, 2.0);
    });

    test('十六进位的 value（0x）也能解析', () {
      final request =
          PaymentUri.parse('ethereum:$_ethAddress?value=0xde0b6b3a7640000');
      expect(request?.amount, 1.0);
    });

    test('各条 EVM 链有自己的 scheme', () {
      expect(
        PaymentUri.parse('base:$_ethAddress?value=1e18')?.chain,
        ChainType.base,
      );
      expect(
        PaymentUri.parse('arbitrum:$_ethAddress')?.chain,
        ChainType.arbitrum,
      );
      expect(PaymentUri.parse('bsc:$_ethAddress')?.chain, ChainType.bsc);
      expect(PaymentUri.parse('bnb:$_ethAddress')?.chain, ChainType.bsc);
    });

    test('scheme 大小写不敏感', () {
      final request = PaymentUri.parse('ETHEREUM:$_ethAddress');
      expect(request?.chain, ChainType.ethereum);
    });

    test('besu scheme 对应联盟链', () {
      final request = PaymentUri.parse('besu:$_ethAddress?value=1');
      expect(request?.chain, ChainType.besu);
    });

    test('@chainId 与 scheme 矛盾时整包拒绝', () {
      // 写著 ethereum 却标 Base 的 chainId：无从判断该走哪条链。
      expect(
        PaymentUri.parse('ethereum:$_ethAddress@8453'),
        isNull,
        reason: '矛盾的 @chainId 必须拒绝，不能默默照 scheme 送',
      );
      // 一致则放行。
      expect(PaymentUri.parse('base:$_ethAddress@8453'), isNotNull);
      expect(PaymentUri.parse('ethereum:$_ethAddress@1'), isNotNull);
      // chainId 由部署决定的链（Besu）不比对。
      expect(PaymentUri.parse('besu:$_ethAddress@1'), isNotNull);
    });

    test('代币转帐不解析（避免误当原生代币）', () {
      expect(
        PaymentUri.parse(
          'ethereum:$_ethAddress?function=transfer&uint256=1',
        ),
        isNull,
      );
    });

    test('不是支付 URI 就回传 null', () {
      expect(PaymentUri.parse('https://example.com'), isNull);
      expect(PaymentUri.parse('hello world'), isNull);
      expect(PaymentUri.parse(_ethAddress), isNull);
    });

    test('纯地址可解析，链由外观推断', () {
      expect(PaymentUri.fromAddress(_ethAddress)?.chain, ChainType.ethereum);
      expect(PaymentUri.fromAddress(_tronAddress)?.chain, ChainType.tron);
      expect(PaymentUri.fromAddress('not-an-address'), isNull);
    });

    test('fromScan 先试支付 URI，再退回纯地址', () {
      final withUri = PaymentUri.fromScan('tron:$_tronAddress?amount=1000000');
      expect(withUri?.chain, ChainType.tron);
      expect(withUri?.amount, 1.0);

      final bare = PaymentUri.fromScan(_ethAddress);
      expect(bare?.chain, ChainType.ethereum);
    });

    test('指定链时，不属于该链的地址解析失败', () {
      // 0x 地址对 TRON 无效；呼叫端可再退回到「自动推断」。
      expect(
        PaymentUri.fromScan(_ethAddress, chain: ChainType.tron),
        isNull,
      );
      expect(
        PaymentUri.fromScan(_tronAddress, chain: ChainType.tron),
        isNotNull,
      );
    });
  });
}
