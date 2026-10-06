/// 通证标准。
///
/// `native` 是链的原生代币（已在余额卡显示），不会出现在下方三个 Tab 里；
/// [erc20] / [erc721] / [erc1155] 才是 Tab 要呈现的内容。
enum TokenStandard {
  native,
  erc20,
  erc721,
  erc1155;

  /// 由设定档字串（小写）还原。
  static TokenStandard fromJson(String? value) => switch (value?.toLowerCase()) {
        'erc20' => TokenStandard.erc20,
        'erc721' => TokenStandard.erc721,
        'erc1155' => TokenStandard.erc1155,
        'native' => TokenStandard.native,
        _ => TokenStandard.erc20,
      };

  /// 是否属于下方三个 Tab 之一（native 不显示在 Tab 里）。
  bool get isTabbed => this != TokenStandard.native;
}

/// 单一通证的定义。
///
/// 来源有二：内建（`assets/tokens.json`，[custom] 为 false）与使用者自订
/// （[custom] 为 true，持久化于 shared_preferences）。
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

  /// 显示名称（例如 USD Coin）。
  final String name;

  /// 代币符号（例如 USDC）。
  final String symbol;

  /// 通证标准。
  final TokenStandard standard;

  /// 链上精度（小数位数）。
  final int decimals;

  /// 合约地址；原生代币为空字串。
  final String address;

  /// 可选的 emoji 图示。
  final String? icon;

  /// 可选的十六进位颜色（#RRGGBB），用于图示底色。
  final String? color;

  /// 是否为使用者自订通证。
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
