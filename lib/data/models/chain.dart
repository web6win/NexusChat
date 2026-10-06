/// 钱包支援的区块链。
///
/// 设计原则：NexusChat 的聊天身份（DID）固定为 `did:ethr`，与链无关；
/// 此处的 `chain` 仅控制「钱包页要显示哪一条链的地址与余额」。
/// 同一把 secp256k1 私钥会同时派生出以太坊 0x 地址与 TRON 的 T 地址
/// （两者的 20 位元组主体完全相同，只是编码方式不同），因此切换链
/// 不需要第二组助记词或第二把金钥。
///
/// 所有 EVM 链（以太坊 / Base / Arbitrum / BSC / WEB6）共用同一个 0x 地址
/// 与同一套 JSON-RPC，新增一条链只需要 [ChainConfig._map] 加一项，
/// 不必动金钥或交易逻辑。
///
/// 预设链为 [ChainType.besu]（WEB6 联盟链，原生代币 Contribution / CNT）。
enum ChainType {
  ethereum,
  base,
  arbitrum,
  bsc,
  tron,

  /// Besu 联盟链（WEB6）。EVM 相容，沿用 0x 地址与 JSON-RPC。
  besu;

  /// 设定/Provider 用的稳定字串，同时也是收款 QR Code 的 URI scheme。
  String get id => switch (this) {
        ChainType.ethereum => 'ethereum',
        ChainType.base => 'base',
        ChainType.arbitrum => 'arbitrum',
        ChainType.bsc => 'bsc',
        ChainType.tron => 'tron',
        ChainType.besu => 'besu',
      };

  /// 是否为 EVM 相容链（地址用 0x + EIP-55，走 JSON-RPC / eth_getBalance）。
  bool get isEvm => this != ChainType.tron;

  static ChainType fromId(String? id) => switch (id) {
        'base' => ChainType.base,
        'arbitrum' => ChainType.arbitrum,
        'bsc' => ChainType.bsc,
        'tron' => ChainType.tron,
        'besu' => ChainType.besu,
        _ => ChainType.ethereum,
      };
}

/// 每条链的技术参数（显示名称走 i18n，不放在这里以免循环依赖）。
class ChainConfig {
  const ChainConfig({
    required this.name,
    required this.symbol,
    required this.explorerHost,
    required this.defaultRpc,
    required this.supportsEns,
    this.expectedChainId,
    this.displayDecimals = 6,
    this.explorerScheme = 'https',
  });

  /// 原生代币全名（Contribution / Ether / TRON）。
  ///
  /// 与 [symbol] 的关系就像「新台币」与「TWD」：前者是给人看的名称，
  /// 后者才是余额与金额旁边显示的代号。
  final String name;

  /// 原生代币代号（CNT / ETH / BNB / TRX）。
  final String symbol;

  /// 区块浏览器主机（用于「在浏览器检视」）。
  final String explorerHost;

  /// 区块浏览器协定（预设 https）。
  final String explorerScheme;

  /// 区块浏览器的完整网址。
  String get explorerUrl => '$explorerScheme://$explorerHost';

  /// 预设 RPC / API 端点。
  final String defaultRpc;

  /// 是否支援 ENS 类域名解析。
  final bool supportsEns;

  /// 余额显示小数位数。
  ///
  /// 注意这是**介面显示**用的位数，不是链上精度：EVM 链的原生代币链上
  /// 精度固定为 18 位（wei），[TxService.sendEvm] 以 `×10^18` 换算，
  /// 与这里无关；TRON 则是 6 位（sun），由 [TxService.sendTron] 处理。
  final int displayDecimals;

  /// 这条链「应该」回报的 chainId（`eth_chainId`）。
  ///
  /// EVM 链的 RPC 端点长得都一样，填错端点（例如把 Base 的 RPC 贴到
  /// 以太坊）时余额仍查得到、交易也送得出去 —— 只是送到错的网路上。
  /// 拿这个值与节点实际回报的 chainId 比对，就能在转帐前挡下来。
  /// 非 EVM 链（TRON）与联盟链（chainId 由部署决定）为 null，表示不比对。
  final int? expectedChainId;

  /// [chainId] 是否与本链不符（端点可能被填错）。
  bool isWrongChain(int? chainId) =>
      expectedChainId != null && chainId != null && chainId != expectedChainId;

  static const Map<ChainType, ChainConfig> _map = <ChainType, ChainConfig>{
    ChainType.ethereum: ChainConfig(
      name: 'Ether',
      symbol: 'ETH',
      explorerHost: 'etherscan.io',
      defaultRpc: 'https://ethereum-rpc.publicnode.com',
      supportsEns: true,
      expectedChainId: 1,
      displayDecimals: 6,
    ),
    ChainType.base: ChainConfig(
      name: 'Ether',
      symbol: 'ETH',
      explorerHost: 'basescan.org',
      defaultRpc: 'https://mainnet.base.org',
      supportsEns: false,
      expectedChainId: 8453,
      displayDecimals: 6,
    ),
    ChainType.arbitrum: ChainConfig(
      name: 'Ether',
      symbol: 'ETH',
      explorerHost: 'arbiscan.io',
      defaultRpc: 'https://arb1.arbitrum.io/rpc',
      supportsEns: false,
      expectedChainId: 42161,
      displayDecimals: 6,
    ),
    ChainType.bsc: ChainConfig(
      name: 'BNB',
      symbol: 'BNB',
      explorerHost: 'bscscan.com',
      defaultRpc: 'https://bsc-dataseed.binance.org',
      supportsEns: false,
      expectedChainId: 56,
      displayDecimals: 4,
    ),
    ChainType.tron: ChainConfig(
      name: 'TRON',
      symbol: 'TRX',
      explorerHost: 'tronscan.org',
      defaultRpc: 'https://api.trongrid.io',
      supportsEns: false,
      displayDecimals: 2,
    ),
    // WEB6 联盟链（Besu）：EVM 相容，原生代币为 Contribution（CNT），
    // 链上精度 18 位（与 EVM 的 wei 一致）。
    // 联盟链通常不接 ENS，故关闭；chainId 由部署决定，因此不做比对。
    ChainType.besu: ChainConfig(
      name: 'Contribution',
      symbol: 'CNT',
      explorerHost: 'scan.web6.win',
      defaultRpc: 'https://chain.web6.win',
      supportsEns: false,
      displayDecimals: 6,
    ),
  };

  static ChainConfig of(ChainType chain) => _map[chain]!;
}
