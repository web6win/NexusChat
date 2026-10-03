plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取固定发布签名配置（key.properties）。缺失时回退到 debug 签名，不影响日常开发。
// 注意：AGP 9 的 new DSL 内置 Kotlin 模式下不暴露 java.util / java.io，
// 因此这里用 kotlin.io 读取并手动解析，避免在 .kts 脚本里引用 java.* 导致编译失败。
val keystorePropertiesFile = rootProject.file("key.properties")
val useReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = mutableMapOf<String, String>()
if (useReleaseSigning) {
    for (line in keystorePropertiesFile.readLines()) {
        val trimmed = line.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#") || trimmed.startsWith("!")) continue
        val eq = trimmed.indexOf('=')
        if (eq > 0) {
            keystoreProperties[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim()
        }
    }
}

android {
    namespace = "win.web6.nexuschat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "win.web6.nexuschat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (useReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 使用固定发布密钥签名，保证不同机器/时间打出的 release 包可覆盖升级。
            signingConfig = if (useReleaseSigning) signingConfigs["release"] else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
