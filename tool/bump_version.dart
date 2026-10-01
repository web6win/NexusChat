import 'dart:io';

/// 遞增 pubspec.yaml 的版本號。
///
/// 用法（在專案根目錄執行）：
/// ```bash
/// dart run tool/bump_version.dart                 # build number +1（預設）
/// dart run tool/bump_version.dart --patch          # 1.0.0 → 1.0.1，build 也 +1
/// dart run tool/bump_version.dart --minor          # 1.0.0 → 1.1.0，build 也 +1
/// dart run tool/bump_version.dart --major          # 1.0.0 → 2.0.0，build 也 +1
/// dart run tool/bump_version.dart --set-build 42   # 直接指定 build number
/// dart run tool/bump_version.dart --no-write       # 只印結果，不改檔案
/// ```
///
/// 設計取捨：
/// - 預設只動 build number（`+1` → `+2`）。語義版本號代表「這版改了什麼」，
///   應該由人決定；build number 只是單調遞增的整數，適合自動化。
/// - 遞增語義版本號時 build number 也一併 +1：商店（App Store / Play）
///   要求 build number 只能往上，不能因為版本號變了就歸零。
/// - 結果以 `name=` / `build=` / `full=` 印到 stdout；在 GitHub Actions 裡
///   （偵測到 `GITHUB_OUTPUT`）會同時寫入該檔案，供後續 job 取用。
///
/// 刻意不引入 yaml 套件：只需要改一行，正則就夠，避免為了工具而增加依賴。
Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('找不到 pubspec.yaml，請在專案根目錄執行。');
    exit(1);
  }

  final text = pubspec.readAsStringSync();
  final match = _versionPattern.firstMatch(text);
  if (match == null) {
    stderr.writeln('pubspec.yaml 裡找不到 "version: x.y.z+n"。');
    exit(1);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  var build = int.parse(match.group(4) ?? '0');

  switch (options.bump) {
    case _Bump.patch:
      patch++;
      break;
    case _Bump.minor:
      minor++;
      patch = 0;
      break;
    case _Bump.major:
      major++;
      minor = 0;
      patch = 0;
      break;
    case _Bump.build:
      break;
  }

  build = options.setBuild ?? build + 1;

  final name = '$major.$minor.$patch';
  final full = '$name+$build';

  if (options.write) {
    final updated = text.replaceFirst(match.group(0)!, 'version: $full');
    pubspec.writeAsStringSync(updated);
  }

  stdout.writeln('name=$name');
  stdout.writeln('build=$build');
  stdout.writeln('full=$full');

  // CI：讓後續 job 能直接拿到這三個值。
  final output = Platform.environment['GITHUB_OUTPUT'];
  if (output != null && output.isNotEmpty) {
    final sink = File(output).openWrite(mode: FileMode.append);
    sink.writeln('name=$name');
    sink.writeln('build=$build');
    sink.writeln('full=$full');
    await sink.flush();
    await sink.close();
  }
}

final RegExp _versionPattern = RegExp(
  r'^version:[ \t]*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+([0-9]+))?[ \t]*$',
  multiLine: true,
);

enum _Bump { build, patch, minor, major }

class _Options {
  const _Options({
    required this.bump,
    required this.write,
    this.setBuild,
  });

  final _Bump bump;
  final bool write;
  final int? setBuild;

  static _Options parse(List<String> args) {
    var bump = _Bump.build;
    var write = true;
    int? setBuild;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--build':
          bump = _Bump.build;
          break;
        case '--patch':
          bump = _Bump.patch;
          break;
        case '--minor':
          bump = _Bump.minor;
          break;
        case '--major':
          bump = _Bump.major;
          break;
        case '--no-write':
          write = false;
          break;
        case '--set-build':
          i++;
          if (i >= args.length) {
            stderr.writeln('--set-build 需要一個整數。');
            exit(1);
          }
          setBuild = int.tryParse(args[i]);
          if (setBuild == null) {
            stderr.writeln('--set-build 需要一個整數，收到：${args[i]}');
            exit(1);
          }
          break;
        default:
          stderr.writeln('未知參數：${args[i]}');
          exit(1);
      }
    }
    return _Options(bump: bump, write: write, setBuild: setBuild);
  }
}
