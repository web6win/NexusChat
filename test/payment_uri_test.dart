import 'package:nexuschat/data/crypto/tron_address.dart';
import 'package:nexuschat/data/ethereum/payment_uri.dart';
import 'package:nexuschat/data/models/chain.dart';
import 'package:test/test.dart';

const String _ethAddress = '0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';

/// 64 位元組的未壓縮公鑰（hex），用來產生一組合法的 TRON 地址。
final String _tronAddress = TronAddress.fromPublicKeyHex('ab' * 64);

void main() {
  group('PaymentUri', () {
    test('EVM 的 value 以 wei 為單位', () {
      final request = PaymentUri.parse('ethereum:$_ethAddress?value=1e18');
      expect(request, isNotNull);
      expect(request!.chain, ChainType.ethereum);
      expect(request.address, _ethAddress);
      expect(request.amount, 1.0);
    });

    test('人類可讀的 value 不會被當成 wei', () {
      final request = PaymentUri.parse('ethereum:$_ethAddress?value=0.5');
      expect(request?.amount, 0.5);
    });

    test('EIP-681 的 @chainId 會被讀出', () {
      final request =
          PaymentUri.parse('ethereum:${_ethAddress}@1?value=0.5');
      expect(request?.requestChainId, 1);
      expect(request?.address, _ethAddress);
      expect(request?.amount, 0.5);
    });

    test('TRON 的 amount 以 sun 為單位', () {
      final request = PaymentUri.parse('tron:$_tronAddress?amount=2000000');
      expect(request, isNotNull);
      expect(request!.chain, ChainType.tron);
      expect(request.address, _tronAddress);
      expect(request.amount, 2.0);
    });

    test('十六進位的 value（0x）也能解析', () {
      final request =
          PaymentUri.parse('ethereum:$_ethAddress?value=0xde0b6b3a7640000');
      expect(request?.amount, 1.0);
    });

    test('各條 EVM 鏈有自己的 scheme', () {
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

    test('scheme 大小寫不敏感', () {
      final request = PaymentUri.parse('ETHEREUM:$_ethAddress');
      expect(request?.chain, ChainType.ethereum);
    });

    test('besu scheme 對應聯盟鏈', () {
      final request = PaymentUri.parse('besu:$_ethAddress?value=1');
      expect(request?.chain, ChainType.besu);
    });

    test('代幣轉帳不解析（避免誤當原生代幣）', () {
      expect(
        PaymentUri.parse(
          'ethereum:$_ethAddress?function=transfer&uint256=1',
        ),
        isNull,
      );
    });

    test('不是支付 URI 就回傳 null', () {
      expect(PaymentUri.parse('https://example.com'), isNull);
      expect(PaymentUri.parse('hello world'), isNull);
      expect(PaymentUri.parse(_ethAddress), isNull);
    });

    test('純地址可解析，鏈由外觀推斷', () {
      expect(PaymentUri.fromAddress(_ethAddress)?.chain, ChainType.ethereum);
      expect(PaymentUri.fromAddress(_tronAddress)?.chain, ChainType.tron);
      expect(PaymentUri.fromAddress('not-an-address'), isNull);
    });

    test('fromScan 先試支付 URI，再退回純地址', () {
      final withUri = PaymentUri.fromScan('tron:$_tronAddress?amount=1000000');
      expect(withUri?.chain, ChainType.tron);
      expect(withUri?.amount, 1.0);

      final bare = PaymentUri.fromScan(_ethAddress);
      expect(bare?.chain, ChainType.ethereum);
    });

    test('指定鏈時，不屬於該鏈的地址解析失敗', () {
      // 0x 地址對 TRON 無效；呼叫端可再退回到「自動推斷」。
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
