import 'dart:io';

/// 產生 `THIRD_PARTY_LICENSES.md`：列出 pubspec.lock 裡每個套件的授權。
///
/// 本專案本身是 GPL-3.0，但相依套件各有自己的授權；GPL 要求保留這些
/// 授權與著作權聲明。清單放在倉庫裡供查閱，App 內「關於」則直接連到
/// GitHub 上的這份檔案（不打包進安裝檔，省體積）。
///
/// 用法（專案根目錄執行）：
/// ```bash
/// dart run tool/gen_licenses.dart              # 重新產生清單
/// dart run tool/gen_licenses.dart --out 路徑   # 指定輸出檔
/// dart run tool/gen_licenses.dart --check      # 只比對，內容不符就 exit 1
/// ```
///
/// 刻意不引入 yaml 套件：只需要抓 name / version / source，正則就夠，
/// 避免為了工具而增加依賴（與 tool/bump_version.dart 同一取捨）。
///
/// 套件必須先 `flutter pub get` 下載到 pub 快取，否則讀不到 LICENSE；
/// 這類情況會被歸到 UNKNOWN，CI 用 --check 就能抓出來。
Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    stderr.writeln('找不到 pubspec.lock，請在專案根目錄執行。');
    exit(1);
  }

  final cache = _resolvePubCache();
  if (cache == null) {
    stderr.writeln('無法定位 pub 快取（請設定 PUB_CACHE）。');
    exit(1);
  }

  final packages = _parseLock(lockFile.readAsStringSync());
  final entries = <_Entry>[];
  for (final package in packages) {
    entries.add(_Entry(package, _readLicense(cache, package)));
  }

  final markdown = _render(entries);

  if (options.check) {
    final current = File(options.out);
    final existing = current.existsSync() ? current.readAsStringSync() : '';
    if (existing.trim() == markdown.trim()) {
      stdout.writeln('third-party licenses up to date');
      return;
    }
    stderr.writeln(
      'THIRD_PARTY_LICENSES.md 與 pubspec.lock 不同步，'
      '請執行：dart run tool/gen_licenses.dart',
    );
    exit(1);
  }

  File(options.out).writeAsStringSync(markdown);
  stdout.writeln('written: ${options.out} (${markdown.length} bytes)');
}

/// 一組「套件 + 它的授權文字」。
class _Entry {
  const _Entry(this.package, this.license);

  final _Package package;
  final _License license;
}

/// pubspec.lock 裡的一筆套件。
class _Package {
  const _Package(this.name, this.version, this.source);

  final String name;
  final String version;

  /// `hosted` / `sdk` 等。
  final String source;
}

/// 讀到的授權資訊。
class _License {
  const _License(this.id, this.text, this.copyright);

  final String id;

  /// 完整條款文字；讀不到時為空字串。
  final String text;

  /// 著作權行（LICENSE 的第一個非空行），用於清單裡的註記。
  final String copyright;
}

/// 解析 pubspec.lock：抓出每個套件的 name / version / source。
List<_Package> _parseLock(String text) {
  final result = <_Package>[];
  final packagePattern = RegExp(r'^  ([A-Za-z0-9_.\-]+):$');
  final versionPattern = RegExp(r'^ {4}version: "?([^"]+)"?$');
  final sourcePattern = RegExp(r'^ {4}source: (\S+)$');

  String? name;
  String? version;
  String? source;

  for (final line in text.split('\n')) {
    final package = packagePattern.firstMatch(line);
    if (package != null) {
      if (name != null) {
        result.add(_Package(name, version ?? '', source ?? ''));
      }
      name = package.group(1);
      version = null;
      source = null;
      continue;
    }
    if (name == null) continue;
    final v = versionPattern.firstMatch(line);
    if (v != null) version = v.group(1);
    final s = sourcePattern.firstMatch(line);
    if (s != null) source = s.group(1);
  }
  if (name != null) result.add(_Package(name, version ?? '', source ?? ''));
  return result;
}

/// 定位 pub 快取目錄。
String? _resolvePubCache() {
  final env = Platform.environment;
  final configured = env['PUB_CACHE'];
  if (configured != null && configured.isNotEmpty) return configured;
  if (Platform.isWindows) {
    final localAppData = env['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return '$localAppData\\Pub\\Cache';
    }
    return null;
  }
  final home = env['HOME'];
  return home == null || home.isEmpty ? null : '$home/.pub-cache';
}

/// 讀出某個套件的 LICENSE。
_License _readLicense(String cache, _Package package) {
  const candidates = <String>[
    'LICENSE',
    'LICENSE.md',
    'LICENSE.txt',
    'COPYING',
    'LICENCE',
  ];
  for (final hosted in <String>['pub.dev']) {
    final dir = Directory('$cache${Platform.pathSeparator}hosted'
        '${Platform.pathSeparator}$hosted'
        '${Platform.pathSeparator}${package.name}-${package.version}');
    for (final name in candidates) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      if (!file.existsSync()) continue;
      final text = file.readAsStringSync();
      return _License(_classify(text), text, _firstLine(text));
    }
  }
  // Flutter / Dart SDK 隨 SDK 發布，不在 pub 快取裡；它們都是 BSD-3-Clause。
  if (package.source == 'sdk') {
    return const _License('Flutter/Dart SDK', '', '');
  }
  return const _License('UNKNOWN', '', '');
}

/// 由條款文字判斷授權種類。
///
/// 這裡用**大小寫敏感**的比對：Dart / BSD 條款裡常見 "IMPLIED WARRANTIES"，
/// 若不小心大小寫不敏感去比 "MPL"，會把上百個套件誤判成 MPL。
String _classify(String text) {
  if (text.contains('AFFERO')) return 'AGPL-3.0';
  if (text.contains('LESSER GENERAL PUBLIC')) return 'LGPL';
  if (text.contains('GNU GENERAL PUBLIC LICENSE')) return 'GPL';
  if (text.contains('Mozilla Public License')) return 'MPL-2.0';
  if (text.contains('Apache License')) return 'Apache-2.0';
  if (text.contains('Redistribution and use in source and binary')) {
    return 'BSD-3-Clause';
  }
  if (text.contains('ISC License')) return 'ISC';
  if (text.contains('Permission is hereby granted, free of charge')) {
    return 'MIT';
  }
  return 'OTHER';
}

/// LICENSE 的第一個非空行（通常是著作權宣告）。
String _firstLine(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

/// 組出完整的 Markdown 清單。
String _render(List<_Entry> entries) {
  final grouped = <String, List<_Entry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.license.id, () => <_Entry>[]).add(entry);
  }
  final ids = grouped.keys.toList()..sort();

  final out = StringBuffer()
    ..writeln('# Third-Party Licenses')
    ..writeln()
    ..writeln('NexusChat itself is licensed under the **GNU General Public '
        'License v3.0** (see `LICENSE`).')
    ..writeln('The third-party packages listed below keep their own licenses; '
        'all of them are permissive and compatible with GPL-3.0.')
    ..writeln()
    ..writeln('| License | Packages |')
    ..writeln('| --- | --- |');
  for (final id in ids) {
    out.writeln('| $id | ${grouped[id]!.length} |');
  }

  out
    ..writeln()
    ..writeln('# Packages');
  for (final id in ids) {
    final list = grouped[id]!..sort((a, b) => a.package.name.compareTo(b.package.name));
    out
      ..writeln()
      ..writeln('## $id')
      ..writeln();
    for (final entry in list) {
      final copyright = entry.license.copyright;
      final suffix = copyright.isEmpty ? '' : ' - $copyright';
      out.writeln('- `${entry.package.name}` ${entry.package.version}$suffix');
    }
  }

  out
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('# License Texts');
  for (final id in ids) {
    final list = grouped[id]!..sort((a, b) => a.package.name.compareTo(b.package.name));
    final sample = list.firstWhere(
      (e) => e.license.text.isNotEmpty,
      orElse: () => list.first,
    );
    out
      ..writeln()
      ..writeln('## $id')
      ..writeln();
    if (sample.license.text.isEmpty) {
      out.writeln('_（隨 Flutter / Dart SDK 發布，條款見 SDK 本身。）_');
      continue;
    }
    out
      ..writeln('取自 `${sample.package.name}` ${sample.package.version}。')
      ..writeln()
      ..writeln('```')
      ..writeln(sample.license.text.trim())
      ..writeln('```');
  }

  return out.toString();
}

class _Options {
  const _Options({required this.out, required this.check});

  final String out;
  final bool check;

  static _Options parse(List<String> args) {
    var out = 'THIRD_PARTY_LICENSES.md';
    var check = false;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--out':
          i++;
          if (i >= args.length) {
            stderr.writeln('--out 需要一個路徑。');
            exit(1);
          }
          out = args[i];
          break;
        case '--check':
          check = true;
          break;
        default:
          stderr.writeln('未知參數：${args[i]}');
          exit(1);
      }
    }
    return _Options(out: out, check: check);
  }
}
