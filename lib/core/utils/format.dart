import 'package:intl/intl.dart';

import '../l10n/strings.dart';

/// 显示格式的共用逻辑。
abstract final class Formatters {
  /// 讯息气泡上的时间：`14:05`
  static String clock(DateTime time) => DateFormat('HH:mm').format(time);

  /// 对话列表上的时间：今天显示时间，昨天显示「昨天」，否则显示日期。
  static String conversationTime(DateTime time, Strings s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(time.year, time.month, time.day);
    if (target == today) return clock(time);
    if (target == today.subtract(const Duration(days: 1))) {
      return s.chatYesterday;
    }
    if (now.difference(time).inDays < 7) {
      return DateFormat('EEE', s.locale.locale.toLanguageTag()).format(time);
    }
    return DateFormat('yyyy/MM/dd').format(time);
  }

  /// 日期分隔线：今天 / 昨天 / 完整日期。
  static String dayLabel(DateTime time, Strings s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(time.year, time.month, time.day);
    if (target == today) return s.chatToday;
    if (target == today.subtract(const Duration(days: 1))) {
      return s.chatYesterday;
    }
    return DateFormat('yyyy/MM/dd').format(time);
  }

  /// 相对时间（「刚刚」、「3 分钟前」）。
  static String relative(DateTime time, Strings s) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return s.timeJustNow;
    if (diff.inMinutes < 60) return s.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.hoursAgo(diff.inHours);
    return DateFormat('yyyy/MM/dd').format(time);
  }

  /// ETH 余额：最多显示 6 位小数。
  static String eth(double? value) {
    if (value == null) return '--';
    if (value == 0) return '0';
    if (value < 0.000001) return value.toStringAsExponential(2);
    return value.toStringAsFixed(value < 1 ? 6 : 4);
  }

  /// 原生代币余额（ETH / TRX 等），依链设定小数位数。
  static String amount(double? value, int decimals) {
    if (value == null) return '--';
    if (value == 0) return '0';
    return value.toStringAsFixed(decimals);
  }
}
