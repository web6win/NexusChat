package win.web6.nexuschat

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexuschat/abi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 依「偏好順序」回傳裝置支援的 ABI，例如 arm64-v8a、armeabi-v7a。
                    // 版本更新會用第一個可用的 ABI 挑對應安裝包，避免下載通用版。
                    "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    else -> result.notImplemented()
                }
            }
    }
}
