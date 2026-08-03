plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dduneon.oun"
    compileSdk = flutter.compileSdkVersion
    // Unity 6이 요구하는 NDK(r27c). flutter.ndkVersion보다 낮으면 unityLibrary 링크가 깨진다.
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dduneon.oun"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage의 EncryptedSharedPreferences가 API 23+ 필요.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Unity가 export 시 이미 압축해둔 리소스를 gradle이 다시 압축하지 않게 한다(로딩 지연 방지).
    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:!CVS:!thumbs.db:!picasa.ini:!*~"
        noCompress += listOf(".unity3d", ".ress", ".resource", ".obb", ".bundle", ".unityexp")
        noCompress +=
            (project.findProperty("unityStreamingAssets") as? String)
                ?.split(",")
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                ?: emptyList()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // Unity export 산출물(android/unityLibrary). settings.gradle.kts에서 include한다.
    implementation(project(":unityLibrary"))
}
