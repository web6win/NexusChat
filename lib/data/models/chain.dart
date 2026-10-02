/// 錢包支援的區塊鏈。
///
/// 設計原則：NexusChat 的聊天身份（DID）固定為 `did:ethr`，與鏈無關；
/// 此處的 `chain` 僅控制「錢包頁要顯示哪一條鏈的地址與餘額」。
/// 同一把 secp256k1 私鑰會同時派生出以太坊 0x 地址與 TRON 的 T 地址
/// （兩者的 20 位元組主體完全相同，只是編碼方式不同），因此切換鏈
/// 不需要第二組助記詞或第二把金鑰。
///
/// 所有 EVM 鏈（以太坊 / Base / Arbitrum / BSC / WEB6）共用同一個 0x 地址
/// 與同一套 JSON-RPC，新增一條鏈只需要 [ChainConfig._map] 加一項，
/// 不必動金鑰或交易邏輯。
///
/// 預設鏈為 [ChainType.besu]（WEB6 聯盟鏈，原生代幣 Contribution / CNT）。
enum ChainType {
  ethereum,
  base,
  arbitrum,
  bsc,
  tron,

  /// Besu 聯盟鏈（WEB6）。EVM 相容，沿用 0x 地址與 JSON-RPC。
  besu;

  /// 設定/Provider 用的穩定字串，同時也是收款 QR Code 的 URI scheme。
  String get id => switch (this) {
        ChainType.ethereum => 'ethereum',
        ChainType.base => 'base',
        ChainType.arbitrum => 'arbitrum',
        ChainType.bsc => 'bsc',
        ChainType.tron => 'tron',
        ChainType.besu => 'besu',
      };

  /// 是否為 EVM 相容鏈（地址用 0x + EIP-55，走 JSON-RPC / eth_getBalance）。
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

/// 每條鏈的技術參數（顯示名稱走 i18n，不放在這裡以免循環依賴）。
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

  /// 原生代幣全名（Contribution / Ether / TRON）。
  ///
  /// 與 [symbol] 的關係就像「新台幣」與「TWD」：前者是給人看的名稱，
  /// 後者才是餘額與金額旁邊顯示的代號。
  final String name;

  /// 原生代幣代號（CNT / ETH / BNB / TRX）。
  final String symbol;

  /// 區塊瀏覽器主機（用於「在瀏覽器檢視」）。
  final String explorerHost;

  /// 區塊瀏覽器協定（預設 https）。
  final String explorerScheme;

  /// 區塊瀏覽器的完整網址。
  String get explorerUrl => '$explorerScheme://$explorerHost';

  /// 預設 RPC / API 端點。
  final String defaultRpc;

  /// 是否支援 ENS 類域名解析。
  final bool supportsEns;

  /// 餘額顯示小數位數。
  ///
  /// 注意這是**介面顯示**用的位數，不是鏈上精度：EVM 鏈的原生代幣鏈上
  /// 精度固定為 18 位（wei），[TxService.sendEvm] 以 `×10^18` 換算，
  /// 與這裡無關；TRON 則是 6 位（sun），由 [TxService.sendTron] 處理。
  final int displayDecimals;

  /// 這條鏈「應該」回報的 chainId（`eth_chainId`）。
  ///
  /// EVM 鏈的 RPC 端點長得都一樣，填錯端點（例如把 Base 的 RPC 貼到
  /// 以太坊）時餘額仍查得到、交易也送得出去 —— 只是送到錯的網路上。
  /// 拿這個值與節點實際回報的 chainId 比對，就能在轉帳前擋下來。
  /// 非 EVM 鏈（TRON）與聯盟鏈（chainId 由部署決定）為 null，表示不比對。
  final int? expectedChainId;

  /// [chainId] 是否與本鏈不符（端點可能被填錯）。
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
    // WEB6 聯盟鏈（Besu）：EVM 相容，原生代幣為 Contribution（CNT），
    // 鏈上精度 18 位（與 EVM 的 wei 一致）。
    // 聯盟鏈通常不接 ENS，故關閉；chainId 由部署決定，因此不做比對。
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
