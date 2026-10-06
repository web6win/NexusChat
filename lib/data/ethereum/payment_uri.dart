import '../models/chain.dart';
import 'tx_service.dart';

/// 扫码解析出的付款请求（原生代币转帐）。
///
/// 只涵盖原生代币（ETH / TRX）：ERC-681 的代币转帐会带
/// `function=transfer`，超出本钱包范围，一律不解析，避免使用者
/// 以为在转 ETH 却送出别的东西。
class PaymentRequest {
  const PaymentRequest({
    required this.chain,
    required this.address,
    this.amount,
    this.requestChainId,
  });

  /// URI 指定的链（`ethereum:` / `tron:` / `besu:`）。
  final ChainType chain;

  final String address;

  /// 金额，人类可读单位（ETH / TRX）。URI 未带金额则为 null。
  final double? amount;

  /// EIP-681 的 `@chainId`（`ethereum:0x…@1`）。
  ///
  /// 解析时会与 scheme 指出的链比对，两者矛盾就整包拒绝（见 [PaymentUri.parse]）。
  final int? requestChainId;
}

/// 支付 URI 解析（ERC-681 / EIP-681 与 TRON 的 `tron:` 形式）。
///
/// 支援的形式：
/// - `ethereum:0xabc…?value=1000000000000000000`
/// - `ethereum:0xabc…@1?value=0.5`（带 chainId）
/// - `tron:T…?amount=100`
/// - `besu:0xabc…?value=1e18`
///
/// 不支援代币转帐（带 `function` / `uint256` 参数者一律回传 null）。
abstract final class PaymentUri {
  static final RegExp _pattern =
      RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]{1,15}):(.+)$');

  static final RegExp _bareAddress = RegExp(
    r'^(0x[0-9a-fA-F]{40}|T[1-9A-HJ-NP-Za-km-z]{33})$',
  );

  /// scheme → 链。与收款页产生的 QR Code（用 [ChainType.id] 当 scheme）对应。
  static ChainType? _chainOf(String scheme) => switch (scheme) {
        'tron' => ChainType.tron,
        'ethereum' || 'eth' => ChainType.ethereum,
        'base' => ChainType.base,
        'arbitrum' || 'arb' => ChainType.arbitrum,
        'bsc' || 'bnb' || 'binance' => ChainType.bsc,
        'besu' || 'web6' => ChainType.besu,
        _ => null,
      };

  /// 解析带 scheme 的支付 URI；不是支付 URI 或内容不合法时回传 null。
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

    // EIP-681 允许在地址后以 `@chainId` 标注链。
    final at = head.indexOf('@');
    final address = at < 0 ? head : head.substring(0, at);
    final chainId = at < 0 ? null : int.tryParse(head.substring(at + 1));

    if (!TxService.isValidAddress(chain, address)) return null;

    // scheme 与 `@chainId` 必须互相一致。两者矛盾时无从判断这笔该走哪条链
    // （例如 `ethereum:0x…@8453`），宁可整包拒绝，也不要让使用者在错的
    // 网路上送出。chainId 由部署决定的链（Besu / TRON）为 null，无法比对。
    final expectedChainId = ChainConfig.of(chain).expectedChainId;
    if (chainId != null && expectedChainId != null && chainId != expectedChainId) {
      return null;
    }

    final params = _query(query);
    // 代币转帐不在支援范围内。
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

  /// 解析「只印地址」的收款码。
  ///
  /// [chain] 指定时会以该链的格式验证；未指定则由地址外观推断
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

  /// 扫码内容 → 付款请求（支付 URI 优先，其次纯地址）。
  static PaymentRequest? fromScan(String raw, {ChainType? chain}) =>
      parse(raw) ?? fromAddress(raw, chain: chain);

  static Map<String, String> _query(String query) {
    if (query.isEmpty) return const <String, String>{};
    try {
      return Uri.splitQueryString(query);
    } catch (_) {
      // query 编码不合法时，宁可拿不到金额也不要让整页坏掉。
      return const <String, String>{};
    }
  }

  /// 金额换算：EVM 的 `value` 以 wei 为单位，TRON 的 `amount` 以 sun 为单位。
  ///
  /// 单位的判定依据是**字面形式**，不是数量级。旧实作拿「是否大于 1 gwei」
  /// 来猜，会把 `value=5` 这种合法的 wei 值误读成 5 颗币（放大 1e18 倍），
  /// 是实实在在的资金风险。规范上 ERC-681 的 `value` 就是整数 wei，因此：
  ///
  /// - **含小数点** → 人类可读单位（规范不允许，但实务上常见且语意明确）；
  /// - **其余**（十进位整数、科学记号、`0x` 十六进位）→ wei / sun，依规范。
  static double? _amount(ChainType chain, String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    // 人类可读：本身就是币的数量，不再换算。
    if (text.contains('.')) {
      final value = double.tryParse(text);
      return (value == null || value <= 0) ? null : value;
    }

    // 整数（含科学记号与十六进位）→ 最小单位。
    final value = lower.startsWith('0x')
        ? BigInt.tryParse(lower.substring(2), radix: 16)?.toDouble()
        : BigInt.tryParse(text)?.toDouble() ?? double.tryParse(text);
    if (value == null || value <= 0) return null;
    return chain == ChainType.tron ? value / 1e6 : value / 1e18;
  }
}
