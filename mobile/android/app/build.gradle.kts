plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "site.codecell.shobuj_mobile"
    // flutter_secure_storage requires compileSdk 37; Flutter's own default
    // (flutter.compileSdkVersion) is currently 36. Overriding is safe since
    // compiling against a newer SDK stays backward compatible with minSdk.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Matches the Android app already registered in the mighty-rider Firebase
        // project (see google-services.json) — FCM's google-services Gradle plugin
        // matches the build's applicationId against a registered package_name.
        applicationId = "com.greensheal.shobuj"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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

flutter {
    source = "../.."
}

dependencies {
    // Required for the app theme to extend Theme.MaterialComponents (see
    // styles.xml) — without it, flutter_stripe's native CardFormField
    // inflates with no visible input fields.
    implementation("com.google.android.material:material:1.12.0")
}
