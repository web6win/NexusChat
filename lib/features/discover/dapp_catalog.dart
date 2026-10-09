import 'package:flutter/material.dart';

import '../../data/models/chain.dart';

/// 浏览器默认页（起始页）按当前网络列出的常用 DApp。
///
/// 仅作「快速入口」用途：点选后以浏览器开启该网址；清单是写死的精选列表，
/// 不联网、不含任何用户资料。不同链给不同的常用 DApp，让起始页随
/// [ChainType]（钱包当前网络）自动切换。
class DappEntry {
  const DappEntry({
    required this.name,
    required this.url,
    required this.icon,
    required this.color,
    this.category,
  });

  /// 显示名称（多为英文专有名词，不随语系变化）。
  final String name;

  /// 要开启的网址。
  final String url;

  /// 列表里用的图标。
  final IconData icon;

  /// 图标底色（用其淡色背景）。
  final Color color;

  /// 简短分类标签，例如 DEX / NFT / Lending（通用缩写，不翻译）。
  final String? category;
}

/// 各链对应的常用 DApp 清单（顺序即展示顺序）。
const Map<ChainType, List<DappEntry>> kDappCatalog = <ChainType, List<DappEntry>>{
  ChainType.ethereum: <DappEntry>[
    DappEntry(
      name: 'Uniswap',
      url: 'https://app.uniswap.org',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFFFF007A),
      category: 'DEX',
    ),
    DappEntry(
      name: 'OpenSea',
      url: 'https://opensea.io',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2081E2),
      category: 'NFT',
    ),
    DappEntry(
      name: 'Etherscan',
      url: 'https://etherscan.io',
      icon: Icons.explore_rounded,
      color: Color(0xFF21325B),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'Aave',
      url: 'https://app.aave.com',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFB6509E),
      category: 'Lending',
    ),
    DappEntry(
      name: 'ENS',
      url: 'https://app.ens.domains',
      icon: Icons.badge_rounded,
      color: Color(0xFF5298FF),
      category: 'Name',
    ),
    DappEntry(
      name: 'Lido',
      url: 'https://stake.lido.fi',
      icon: Icons.upload_rounded,
      color: Color(0xFF00A3FF),
      category: 'Staking',
    ),
  ],
  ChainType.base: <DappEntry>[
    DappEntry(
      name: 'Aerodrome',
      url: 'https://aerodrome.finance',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF0052FF),
      category: 'DEX',
    ),
    DappEntry(
      name: 'Uniswap',
      url: 'https://app.uniswap.org',
      icon: Icons.currency_exchange_rounded,
      color: Color(0xFFFF007A),
      category: 'DEX',
    ),
    DappEntry(
      name: 'BaseScan',
      url: 'https://basescan.org',
      icon: Icons.explore_rounded,
      color: Color(0xFF0052FF),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'Zora',
      url: 'https://zora.co',
      icon: Icons.storefront_rounded,
      color: Color(0xFF111111),
      category: 'NFT',
    ),
    DappEntry(
      name: 'OpenSea',
      url: 'https://opensea.io',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2081E2),
      category: 'NFT',
    ),
    DappEntry(
      name: 'Base',
      url: 'https://base.org',
      icon: Icons.public_rounded,
      color: Color(0xFF0052FF),
      category: 'Info',
    ),
  ],
  ChainType.arbitrum: <DappEntry>[
    DappEntry(
      name: 'Uniswap',
      url: 'https://app.uniswap.org',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFFFF007A),
      category: 'DEX',
    ),
    DappEntry(
      name: 'Arbiscan',
      url: 'https://arbiscan.io',
      icon: Icons.explore_rounded,
      color: Color(0xFF28A0F0),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'GMX',
      url: 'https://app.gmx.io',
      icon: Icons.show_chart_rounded,
      color: Color(0xFF2D9CDB),
      category: 'Perp',
    ),
    DappEntry(
      name: 'Camelot',
      url: 'https://camelot.exchange',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFFF6B73C),
      category: 'DEX',
    ),
    DappEntry(
      name: 'Arbitrum Bridge',
      url: 'https://bridge.arbitrum.io',
      icon: Icons.lan_rounded,
      color: Color(0xFF28A0F0),
      category: 'Bridge',
    ),
    DappEntry(
      name: 'OpenSea',
      url: 'https://opensea.io',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2081E2),
      category: 'NFT',
    ),
  ],
  ChainType.bsc: <DappEntry>[
    DappEntry(
      name: 'PancakeSwap',
      url: 'https://pancakeswap.finance',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFFD1884F),
      category: 'DEX',
    ),
    DappEntry(
      name: 'BscScan',
      url: 'https://bscscan.com',
      icon: Icons.explore_rounded,
      color: Color(0xFFF0B90B),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'Venus',
      url: 'https://app.venus.io',
      icon: Icons.savings_rounded,
      color: Color(0xFFFACC15),
      category: 'Lending',
    ),
    DappEntry(
      name: 'Binance',
      url: 'https://www.binance.com',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFF0B90B),
      category: 'CEX',
    ),
    DappEntry(
      name: 'OpenSea',
      url: 'https://opensea.io',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2081E2),
      category: 'NFT',
    ),
    DappEntry(
      name: 'Biswap',
      url: 'https://biswap.org',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF1FA968),
      category: 'DEX',
    ),
  ],
  ChainType.tron: <DappEntry>[
    DappEntry(
      name: 'SunSwap',
      url: 'https://sunswap.com',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFFE60012),
      category: 'DEX',
    ),
    DappEntry(
      name: 'JustLend',
      url: 'https://sun.io',
      icon: Icons.savings_rounded,
      color: Color(0xFFFFB300),
      category: 'Lending',
    ),
    DappEntry(
      name: 'Tronscan',
      url: 'https://tronscan.org',
      icon: Icons.explore_rounded,
      color: Color(0xFFE60012),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'TronLink',
      url: 'https://www.tronlink.org',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF2D9CDB),
      category: 'Wallet',
    ),
    DappEntry(
      name: 'APENFT',
      url: 'https://apenft.org',
      icon: Icons.storefront_rounded,
      color: Color(0xFFD4AF37),
      category: 'NFT',
    ),
    DappEntry(
      name: 'Steemit',
      url: 'https://steemit.com',
      icon: Icons.public_rounded,
      color: Color(0xFF005BAC),
      category: 'Social',
    ),
  ],
  // WEB6 联盟链（Besu）：项目自有生态，列官方入口与区块浏览器。
  ChainType.besu: <DappEntry>[
    DappEntry(
      name: 'WEB6 Explorer',
      url: 'https://scan.web6.win',
      icon: Icons.explore_rounded,
      color: Color(0xFF6C5CE7),
      category: 'Explorer',
    ),
    DappEntry(
      name: 'WEB6 Chain',
      url: 'https://chain.web6.win',
      icon: Icons.lan_rounded,
      color: Color(0xFF6C5CE7),
      category: 'Node',
    ),
    DappEntry(
      name: 'WEB6 Official',
      url: 'https://web6.win',
      icon: Icons.public_rounded,
      color: Color(0xFF6C5CE7),
      category: 'Info',
    ),
    DappEntry(
      name: 'NexusChat',
      url: 'https://nexuschat.web6.win',
      icon: Icons.chat_rounded,
      color: Color(0xFF6C5CE7),
      category: 'App',
    ),
  ],
};

/// 取得某条链对应的常用 DApp 清单（没有则回传空列表）。
List<DappEntry> dappsFor(ChainType chain) =>
    kDappCatalog[chain] ?? const <DappEntry>[];
