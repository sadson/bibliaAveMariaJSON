plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.santosapp.bible_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.santosapp.bible_app"
        minSdk = flutter.minSdkVersion
        // Flutter 3.44+ usa targetSdkVersion=36 (Android 16), que exige alinhamento
        // obrigatório de 16 KB em libs nativas. libonnxruntime.so e libsqlite3.so
        // ainda não têm builds alinhadas; fixar em 35 evita o enforcement do API 36.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // useLegacyPackaging=true extrai as .so para o filesystem na instalação,
    // contornando a verificação de alinhamento de página do Android 15/16.
    // Tem precedência sobre android:extractNativeLibs no manifesto.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
