import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 显示浮动提示（SnackBar）。
///
/// 桌面浏览器视窗很宽时，SnackBar 预设会横贯整个画面，看起来像是坏掉；
/// 这里在宽度足够时收敛成固定宽度并置中，行动装置则维持满宽。
///
/// 同时先关掉目前这一则，避免连续复制时提示排队堆叠。
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
