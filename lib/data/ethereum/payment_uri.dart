import '../models/chain.dart';
import 'tx_service.dart';

/// 掃碼解析出的付款請求（原生代幣轉帳）。
///
/// 只涵蓋原生代幣（ETH / TRX）：ERC-681 的代幣轉帳會帶
/// `function=transfer`，超出本錢包範圍，一律不解析，避免使用者
/// 以為在轉 ETH 卻送出別的東西。
class PaymentRequest {
  const PaymentRequest({
    required this.chain,
    required this.address,
    this.amount,
    this.requestChainId,
  });

  /// URI 指定的鏈（`ethereum:` / `tron:` / `besu:`）。
  final ChainType chain;

  final String address;

  /// 金額，人類可讀單位（ETH / TRX）。URI 未帶金額則為 null。
  final double? amount;

  /// EIP-681 的 `@chainId`（`ethereum:0x…@1`），僅供提示與比對。
  final int? requestChainId;
}

/// 支付 URI 解析（ERC-681 / EIP-681 與 TRON 的 `tron:` 形式）。
///
/// 支援的形式：
/// - `ethereum:0xabc…?value=1000000000000000000`
/// - `ethereum:0xabc…@1?value=0.5`（帶 chainId）
/// - `tron:T…?amount=100`
/// - `besu:0xabc…?value=1e18`
///
/// 不支援代幣轉帳（帶 `function` / `uint256` 參數者一律回傳 null）。
abstract final class PaymentUri {
  static final RegExp _pattern =
      RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]{1,15}):(.+)$');

  static final RegExp _bareAddress = RegExp(
    r'^(0x[0-9a-fA-F]{40}|T[1-9A-HJ-NP-Za-km-z]{33})$',
  );

  /// scheme → 鏈。與收款頁產生的 QR Code（用 [ChainType.id] 當 scheme）對應。
  static ChainType? _chainOf(String scheme) => switch (scheme) {
        'tron' => ChainType.tron,
        'ethereum' || 'eth' => ChainType.ethereum,
        'base' => ChainType.base,
        'arbitrum' || 'arb' => ChainType.arbitrum,
        'bsc' || 'bnb' || 'binance' => ChainType.bsc,
        'besu' || 'web6' => ChainType.besu,
        _ => null,
      };

  /// 解析帶 scheme 的支付 URI；不是支付 URI 或內容不合法時回傳 null。
  static PaymentRequest? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
    final match = _pattern.firstMatch(text);
    if (match == null) return null;

    final chain = _chainOf(match.group(1)!.toLowerCase());
    if (chain == null) return null;

    final rest = match.group(2)!;
    final question = rest.indexOf('?');
    final head = question < 0 ? rest : rest.substring(0, question);
    final query = question < 0 ? '' : rest.substring(question + 1);

    // EIP-681 允許在地址後以 `@chainId` 標註鏈。
    final at = head.indexOf('@');
    final address = at < 0 ? head : head.substring(0, at);
    final chainId = at < 0 ? null : int.tryParse(head.substring(at + 1));

    if (!TxService.isValidAddress(chain, address)) return null;

    final params = _query(query);
    // 代幣轉帳不在支援範圍內。
    if (params.containsKey('function') || params.containsKey('uint256')) {
      return null;
    }
    return PaymentRequest(
      chain: chain,
      address: address,
      amount: _amount(chain, params['value'] ?? params['amount']),
      requestChainId: chainId,
    );
  }

  /// 解析「只印地址」的收款碼。
  ///
  /// [chain] 指定時會以該鏈的格式驗證；未指定則由地址外觀推斷
  /// （0x → EVM，T → TRON）。
  static PaymentRequest? fromAddress(String raw, {ChainType? chain}) {
    final text = raw.trim();
    if (!_bareAddress.hasMatch(text)) return null;
    if (chain != null) {
      return TxService.isValidAddress(chain, text)
          ? PaymentRequest(chain: chain, address: text)
          : null;
    }
    final inferred =
        text.toLowerCase().startsWith('0x') ? ChainType.ethereum : ChainType.tron;
    return PaymentRequest(chain: inferred, address: text);
  }

  /// 掃碼內容 → 付款請求（支付 URI 優先，其次純地址）。
  static PaymentRequest? fromScan(String raw, {ChainType? chain}) =>
      parse(raw) ?? fromAddress(raw, chain: chain);

  static Map<String, String> _query(String query) {
    if (query.isEmpty) return const <String, String>{};
    try {
      return Uri.splitQueryString(query);
    } catch (_) {
      // query 編碼不合法時，寧可拿不到金額也不要讓整頁壞掉。
      return const <String, String>{};
    }
  }

  /// 金額換算：EVM 的 `value` 以 wei 為單位，TRON 的 `amount` 以 sun
  /// 為單位；部分產生器直接寫人類可讀數字，這裡以數量級判斷。
  ///
  /// 門檻取 1 gwei（1e9 wei）/ 0.001 TRX（1e3 sun）—— 低於門檻的轉帳
  /// 金額實務上不存在，視為已經是人類可讀單位。
  static double? _amount(ChainType chain, String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    final value = lower.startsWith('0x')
        ? BigInt.tryParse(lower.substring(2), radix: 16)?.toDouble()
        : double.tryParse(text);
    if (value == null || value <= 0) return null;
    if (chain == ChainType.tron) return value >= 1e3 ? value / 1e6 : value;
    return value >= 1e9 ? value / 1e18 : value;
  }
}
