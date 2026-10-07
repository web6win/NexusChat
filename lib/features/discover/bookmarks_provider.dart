import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 浏览器收藏（书签）在 shared_preferences 的键名。
const _bookmarksPrefsKey = 'browser_bookmarks_v1';

/// 一笔浏览器收藏。
class Bookmark {
  const Bookmark({
    required this.url,
    required this.addedAtMs,
    this.title,
  });

  final String url;

  /// 收藏当下页面的标题（目前以网址的 host 表示）。
  final String? title;
  final int addedAtMs;

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        url: json['url'] as String? ?? '',
        title: json['title'] as String?,
        addedAtMs: json['ts'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        if (title != null) 'title': title,
        'ts': addedAtMs,
      };
}

/// 浏览器收藏，持久化于 shared_preferences，最新的排在最前面。
final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    _load();
    return const <Bookmark>[];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarksPrefsKey);
    if (raw == null || raw.isEmpty) {
      state = const <Bookmark>[];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .where((b) => b.url.isNotEmpty)
          .toList();
    } catch (_) {
      state = const <Bookmark>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bookmarksPrefsKey,
      jsonEncode(state.map((b) => b.toJson()).toList()),
    );
  }

  /// 加入收藏；已存在则移到最前面，不重复新增。
  Future<void> add(Bookmark bookmark) async {
    if (bookmark.url.isEmpty) return;
    state = <Bookmark>[
      bookmark,
      ...state.where((b) => b.url != bookmark.url),
    ];
    await _persist();
  }

  Future<void> remove(String url) async {
    state = state.where((b) => b.url != url).toList();
    await _persist();
  }

  bool contains(String url) => state.any((b) => b.url == url);
}
