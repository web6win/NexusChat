import 'package:intl/intl.dart';

import '../l10n/strings.dart';

/// 顯示格式的共用邏輯。
abstract final class Formatters {
  /// 訊息氣泡上的時間：`14:05`
  static String clock(DateTime time) => DateFormat('HH:mm').format(time);

  /// 對話列表上的時間：今天顯示時間，昨天顯示「昨天」，否則顯示日期。
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

  /// 日期分隔線：今天 / 昨天 / 完整日期。
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

  /// 相對時間（「剛剛」、「3 分鐘前」）。
  static String relative(DateTime time, Strings s) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return s.timeJustNow;
    if (diff.inMinutes < 60) return s.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.hoursAgo(diff.inHours);
    return DateFormat('yyyy/MM/dd').format(time);
  }

  /// ETH 餘額：最多顯示 6 位小數。
  static String eth(double? value) {
    if (value == null) return '--';
    if (value == 0) return '0';
    if (value < 0.000001) return value.toStringAsExponential(2);
    return value.toStringAsFixed(value < 1 ? 6 : 4);
  }

  /// 原生代幣餘額（ETH / TRX 等），依鏈設定小數位數。
  static String amount(double? value, int decimals) {
    if (value == null) return '--';
    if (value == 0) return '0';
    return value.toStringAsFixed(decimals);
  }
}
