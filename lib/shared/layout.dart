import 'package:flutter/material.dart';

/// 响应式版面的断点与宽度上限。
///
/// 集中定义于此，让壳层、各页面与聊天视图对「多宽算宽」有同一套认知，
/// 避免每个页面各自写一组魔法数字而彼此不一致。
abstract final class AppBreakpoints {
  /// 一般内容页（设定、钱包、身份、清单）的最大内容宽度。
  ///
  /// 760 是「表单 + 卡片」在桌机上仍易读、又不至于显得空旷的区间。
  static const content = 760.0;

  /// 对话讯息区的最大宽度；比 [content] 略宽，但仍避免长行难以阅读。
  static const conversation = 900.0;

  /// 双栏版面（对话清单 + 讯息区）时，清单栏的固定宽度。
  static const conversationList = 360.0;

  /// 壳层由底部导览改为左侧导览列的宽度门槛。
  static const rail = 900.0;

  /// 目前是否采用左侧导览列版面。
  static bool usesRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= rail;
}

/// 限宽并水平置中的内容容器。
///
/// 壳层内部的页面在桌面浏览器上会拿到非常宽的约束；若放任卡片横向铺满
/// 整个视窗，阅读动线会被拉得过长、留白也失去意义。这里把内容收在
/// [maxWidth] 之内并置中；行动装置（视窗宽度不足）时行为与不加容器完全
/// 相同，因此可以无条件套用。
///
/// 垂直方向刻意采「顶部对齐」而非置中：表单与清单在切换内容时高度会变，
/// 若连垂直也置中，标题会随内容高度上下跳动。
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    required this.child,
    super.key,
    this.maxWidth = AppBreakpoints.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 统一的页首：大标题 + 选用副标 + 右侧动作。
///
/// 各页原本各自写 `Padding + Text`，内距与字距略有出入；集中成元件后
/// 标题在页面之间切换时位置不会位移。
///
/// 预设左内距 20 是刻意对齐 [SectionCard] 的标题（外层 16 + 标题本身 4）。
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(20, 10, 12, 8),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }
}
