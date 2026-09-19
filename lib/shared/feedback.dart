import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 顯示浮動提示（SnackBar）。
///
/// 桌面瀏覽器視窗很寬時，SnackBar 預設會橫貫整個畫面，看起來像是壞掉；
/// 這裡在寬度足夠時收斂成固定寬度並置中，行動裝置則維持滿寬。
///
/// 同時先關掉目前這一則，避免連續複製時提示排隊堆疊。
void showAppSnack(
  BuildContext context,
  String message, {
  bool danger = false,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: wide ? 420 : null,
        backgroundColor: danger ? AppColors.danger : null,
      ),
    );
}
