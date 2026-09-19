import 'package:flutter/material.dart';

/// 響應式版面的斷點與寬度上限。
///
/// 集中定義於此，讓殼層、各頁面與聊天視圖對「多寬算寬」有同一套認知，
/// 避免每個頁面各自寫一組魔法數字而彼此不一致。
abstract final class AppBreakpoints {
  /// 一般內容頁（設定、錢包、身份、清單）的最大內容寬度。
  ///
  /// 760 是「表單 + 卡片」在桌機上仍易讀、又不至於顯得空曠的區間。
  static const content = 760.0;

  /// 對話訊息區的最大寬度；比 [content] 略寬，但仍避免長行難以閱讀。
  static const conversation = 900.0;

  /// 雙欄版面（對話清單 + 訊息區）時，清單欄的固定寬度。
  static const conversationList = 360.0;

  /// 殼層由底部導覽改為左側導覽列的寬度門檻。
  static const rail = 900.0;

  /// 目前是否採用左側導覽列版面。
  static bool usesRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= rail;
}

/// 限寬並水平置中的內容容器。
///
/// 殼層內部的頁面在桌面瀏覽器上會拿到非常寬的約束；若放任卡片橫向鋪滿
/// 整個視窗，閱讀動線會被拉得過長、留白也失去意義。這裡把內容收在
/// [maxWidth] 之內並置中；行動裝置（視窗寬度不足）時行為與不加容器完全
/// 相同，因此可以無條件套用。
///
/// 垂直方向刻意採「頂部對齊」而非置中：表單與清單在切換內容時高度會變，
/// 若連垂直也置中，標題會隨內容高度上下跳動。
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

/// 統一的頁首：大標題 + 選用副標 + 右側動作。
///
/// 各頁原本各自寫 `Padding + Text`，內距與字距略有出入；集中成元件後
/// 標題在頁面之間切換時位置不會位移。
///
/// 預設左內距 20 是刻意對齊 [SectionCard] 的標題（外層 16 + 標題本身 4）。
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
                    fontSize: 27,
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
