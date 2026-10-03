/// 通證標準。
///
/// `native` 是鏈的原生代幣（已在餘額卡顯示），不會出現在下方三個 Tab 裡；
/// [erc20] / [erc721] / [erc1155] 才是 Tab 要呈現的內容。
enum TokenStandard {
  native,
  erc20,
  erc721,
  erc1155;

  /// 由設定檔字串（小寫）還原。
  static TokenStandard fromJson(String? value) => switch (value?.toLowerCase()) {
        'erc20' => TokenStandard.erc20,
        'erc721' => TokenStandard.erc721,
        'erc1155' => TokenStandard.erc1155,
        'native' => TokenStandard.native,
        _ => TokenStandard.erc20,
      };

  /// 是否屬於下方三個 Tab 之一（native 不顯示在 Tab 裡）。
  bool get isTabbed => this != TokenStandard.native;
}

/// 單一通證的定義。
///
/// 來源有二：內建（`assets/tokens.json`，[custom] 為 false）與使用者自訂
/// （[custom] 為 true，持久化於 shared_preferences）。
class TokenDef {
  const TokenDef({
    required this.name,
    required this.symbol,
    required this.standard,
    required this.decimals,
    required this.address,
    this.icon,
    this.color,
    this.custom = false,
  });

  /// 顯示名稱（例如 USD Coin）。
  final String name;

  /// 代幣符號（例如 USDC）。
  final String symbol;

  /// 通證標準。
  final TokenStandard standard;

  /// 鏈上精度（小數位數）。
  final int decimals;

  /// 合約地址；原生代幣為空字串。
  final String address;

  /// 可選的 emoji 圖示。
  final String? icon;

  /// 可選的十六進位顏色（#RRGGBB），用於圖示底色。
  final String? color;

  /// 是否為使用者自訂通證。
  final bool custom;

  factory TokenDef.fromJson(Map<String, dynamic> json) => TokenDef(
        name: (json['name'] as String?)?.trim() ?? '',
        symbol: (json['symbol'] as String?)?.trim() ?? '',
        standard: TokenStandard.fromJson(json['type'] as String?),
        decimals: (json['decimals'] as int?) ?? 18,
        address: (json['address'] as String?)?.trim() ?? '',
        icon: (json['icon'] as String?)?.trim(),
        color: (json['color'] as String?)?.trim(),
        custom: (json['custom'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'symbol': symbol,
        'type': standard.name,
        'decimals': decimals,
        'address': address,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        'custom': true,
      };

  TokenDef copyWith({bool? custom}) => TokenDef(
        name: name,
        symbol: symbol,
        standard: standard,
        decimals: decimals,
        address: address,
        icon: icon,
        color: color,
        custom: custom ?? this.custom,
      );
}
