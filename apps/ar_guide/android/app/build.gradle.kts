plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jp.tasuku.ar_guide"
    // Demo phone: AQUOS wish4 on Android 16 (API 36).
    compileSdk = 36
    // Flutter 3.47 defaults to NDK 28.2; this app has no native code of its own, so the NDK that is
    // already installed on the dev machine is used. Change it if your SDK has another NDK version.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs it.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "jp.tasuku.ar_guide"
        // minSdk 24 = Flutter's default, also enough for ARCore 1.57 and the camera plugin (CameraX).
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // ARCore SDK: optional upgrade (plane finding) used only on ARCore-supported phones; the compass
    // mode needs no ARCore. Rendering is plain OpenGL ES, no Sceneform / SceneView.
    implementation("com.google.ar:core:1.57.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Firebase needs android/app/google-services.json (not in Git). Without it the app still builds and starts;
// Live alerts then shows "エラー".
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
