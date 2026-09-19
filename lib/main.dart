import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/core.dart';
import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'state/controllers.dart';
import 'ui/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 只載入設定與公開提示；秘密要等使用者在鎖屏輸入密碼才會進入記憶體。
  final core = await Core.bootstrap();

  runApp(
    ProviderScope(
      overrides: <Override>[coreProvider.overrideWithValue(core)],
      child: const NexusChatApp(),
    ),
  );
}

/// 應用程式根元件：主題、語系、路由，以及**閒置自動鎖定**的輸入監聽。
class NexusChatApp extends ConsumerStatefulWidget {
  const NexusChatApp({super.key});

  @override
  ConsumerState<NexusChatApp> createState() => _NexusChatAppState();
}

class _NexusChatAppState extends ConsumerState<NexusChatApp> {
  late final AppLifecycleListener _lifecycle;

  /// 鍵盤事件處理器：讓「只用鍵盤」的操作也能延後自動鎖定。
  late final KeyEventCallback _keyHandler;

  @override
  void initState() {
    super.initState();

    // 頁面切到背景時（若使用者開啟 lockOnHide）立即鎖定。
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(sessionProvider.notifier).onAppHidden(),
      onPause: () => ref.read(sessionProvider.notifier).onAppHidden(),
    );

    _keyHandler = (KeyEvent event) {
      if (event is KeyDownEvent) {
        ref.read(sessionProvider.notifier).noteActivity();
      }
      // 回傳 false 表示不消費事件，讓它繼續傳遞給其他處理器。
      return false;
    };
    HardwareKeyboard.instance.addHandler(_keyHandler);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    super.dispose();
  }

  void _noteActivity() =>
      ref.read(sessionProvider.notifier).noteActivity();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);

    // 指標與鍵盤活動都會重置閒置計時器（控制器內部已做 10 秒節流）。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _noteActivity(),
      onPointerHover: (_) => _noteActivity(),
      onPointerSignal: (_) => _noteActivity(),
      child: MaterialApp.router(
        title: 'NexusChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: settings.theme.themeMode,
        locale: locale?.locale,
        supportedLocales: StringsDelegate.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<Object>>[
          const StringsDelegate(),
          ...globalLocalizationsDelegates,
        ],
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
