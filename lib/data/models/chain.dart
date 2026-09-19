/// 錢包支援的區塊鏈。
///
/// 設計原則：NexusChat 的聊天身份（DID）固定為 `did:ethr`，與鏈無關；
/// 此處的 `chain` 僅控制「錢包頁要顯示哪一條鏈的地址與餘額」。
/// 同一把 secp256k1 私鑰會同時派生出以太坊 0x 地址與 TRON 的 T 地址
/// （兩者的 20 位元組主體完全相同，只是編碼方式不同），因此切換鏈
/// 不需要第二組助記詞或第二把金鑰。
enum ChainType {
  ethereum,
  tron,

  /// Besu 聯盟鏈（WEB6）。EVM 相容，沿用 0x 地址與 JSON-RPC。
  besu;

  /// 設定/Provider 用的穩定字串。
  String get id => switch (this) {
        ChainType.ethereum => 'ethereum',
        ChainType.tron => 'tron',
        ChainType.besu => 'besu',
      };

  /// 是否為 EVM 相容鏈（地址用 0x + EIP-55，走 JSON-RPC / eth_getBalance）。
  bool get isEvm => this != ChainType.tron;

  static ChainType fromId(String? id) => switch (id) {
        'tron' => ChainType.tron,
        'besu' => ChainType.besu,
        _ => ChainType.ethereum,
      };
}

/// 每條鏈的技術參數（顯示名稱走 i18n，不放在這裡以免循環依賴）。
class ChainConfig {
  const ChainConfig({
    required this.symbol,
    required this.explorerHost,
    required this.defaultRpc,
    required this.supportsEns,
    this.displayDecimals = 6,
    this.explorerScheme = 'https',
  });

  /// 原生代幣符號（ETH / TRX）。
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
  final int displayDecimals;

  static const Map<ChainType, ChainConfig> _map = <ChainType, ChainConfig>{
    ChainType.ethereum: ChainConfig(
      symbol: 'ETH',
      explorerHost: 'etherscan.io',
      defaultRpc: 'https://ethereum-rpc.publicnode.com',
      supportsEns: true,
      displayDecimals: 6,
    ),
    ChainType.tron: ChainConfig(
      symbol: 'TRX',
      explorerHost: 'tronscan.org',
      defaultRpc: 'https://api.trongrid.io',
      supportsEns: false,
      displayDecimals: 2,
    ),
    // Besu 聯盟鏈（WEB6）：EVM 相容，原生代幣沿用 18 位小數的 ETH 計價。
    // 聯盟鏈通常不接 ENS，故關閉。
    ChainType.besu: ChainConfig(
      symbol: 'ETH',
      explorerHost: 'scan.web6.win',
      defaultRpc: 'https://chain.web6.win',
      supportsEns: false,
      displayDecimals: 6,
    ),
  };

  static ChainConfig of(ChainType chain) => _map[chain]!;
}
