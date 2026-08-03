pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // FCM: google-services.json을 읽어 리소스로 굽는다(app 모듈에서 apply).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")

// Unity export 산출물(UaaL). gitignore되어 있어 클론 직후에는 없다 —
// Unity 에디터에서 `Flutter Embed → Export project to Flutter app → Android`로
// android/unityLibrary에 내보내야 한다. (BUILD.md 참고)
require(file("unityLibrary/build.gradle").exists()) {
    "android/unityLibrary가 없습니다. Unity 에디터에서 Android로 export하세요 (BUILD.md의 'Android' 절 참고)."
}
include(":unityLibrary")
