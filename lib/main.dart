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

  // 只载入设定与公开提示；秘密要等使用者在锁屏输入密码才会进入记忆体。
  final core = await Core.bootstrap();

  runApp(
    ProviderScope(
      overrides: <Override>[coreProvider.overrideWithValue(core)],
      child: const NexusChatApp(),
    ),
  );
}

/// 应用程式根元件：主题、语系、路由，以及**闲置自动锁定**的输入监听。
class NexusChatApp extends ConsumerStatefulWidget {
  const NexusChatApp({super.key});

  @override
  ConsumerState<NexusChatApp> createState() => _NexusChatAppState();
}

class _NexusChatAppState extends ConsumerState<NexusChatApp> {
  late final AppLifecycleListener _lifecycle;

  /// 键盘事件处理器：让「只用键盘」的操作也能延后自动锁定。
  late final KeyEventCallback _keyHandler;

  @override
  void initState() {
    super.initState();

    // 页面切到背景时（若使用者开启 lockOnHide）立即锁定。
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(sessionProvider.notifier).onAppHidden(),
      onPause: () => ref.read(sessionProvider.notifier).onAppHidden(),
    );

    _keyHandler = (KeyEvent event) {
      if (event is KeyDownEvent) {
        ref.read(sessionProvider.notifier).noteActivity();
      }
      // 回传 false 表示不消费事件，让它继续传递给其他处理器。
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

    // 指标与键盘活动都会重置闲置计时器（控制器内部已做 10 秒节流）。
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
