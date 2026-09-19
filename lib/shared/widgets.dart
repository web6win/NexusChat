import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../data/crypto/did.dart';

/// 圓形頭像：顯示縮寫，並可帶上狀態點。
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    required this.color,
    super.key,
    this.size = 48,
    this.showPresence = false,
    this.present = false,
    this.ring = false,
  });

  final String name;
  final Color color;
  final double size;
  final bool showPresence;
  final bool present;
  final bool ring;

  String _initials() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    if (trimmed.startsWith('0x')) {
      return trimmed.substring(2, 4).toUpperCase();
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + (showPresence ? 4 : 0),
      height: size + (showPresence ? 4 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[color, color.withValues(alpha: 0.72)],
              ),
              border: ring
                  ? Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (showPresence)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: present ? AppColors.success : const Color(0xFF9AA0B4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 帶標題的分區容器。
///
/// 左右不留邊距，交由外層捲動視圖統一把內容收在 [AppGap.lg] 之內，
/// 這樣同一個頁面裡的卡片、按鈕與頁首才會對齊在同一條垂直線上。
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// 一列可點擊的設定項目。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger
        ? AppColors.danger
        : (iconColor ?? theme.colorScheme.primary);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? AppColors.danger : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                )
              : null),
    );
  }
}

/// 空狀態畫面。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.brand.withValues(alpha: 0.16),
                    AppColors.accent.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: Icon(icon, size: 40, color: AppColors.brand),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 等寬的識別碼文字（DID / 地址 / 金鑰）。
class MonoText extends StatelessWidget {
  const MonoText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
        );
    return Text(
      text,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(
        fontFamily: 'monospace',
        letterSpacing: -0.2,
        height: 1.45,
      ),
    );
  }
}

/// 小徽章（例如「端到端加密」、「Waku」）。
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    super.key,
    this.icon,
    this.color,
    this.onBackground = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool onBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: onBackground ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 顯示地址／DID 並提供複製的小工具列。
class AddressChip extends StatelessWidget {
  const AddressChip({
    required this.value,
    super.key,
    this.onCopy,
    this.icon = Icons.badge_outlined,
  });

  final String value;
  final VoidCallback? onCopy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onCopy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: MonoText(Did.shortAddress(value, head: 10, tail: 6)),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主題選擇卡片（用於設定的外觀區塊）。
class ThemeOptionCard extends StatelessWidget {
  const ThemeOptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? AppColors.brand.withValues(alpha: 0.12)
                : theme.colorScheme.onSurface.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? AppColors.brand
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.brand : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.brand : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
