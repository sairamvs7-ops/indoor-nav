plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.indoornav.indoor_nav_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.indoornav.indoor_nav_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24 // opencv_dart prebuilt libraries need API 24+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One shared key for test builds, so an APK from CI installs over one built
    // on another machine (Android refuses updates signed with a different key).
    // It is public, in the repo: never use it for a Play Store release.
    signingConfigs {
        create("test") {
            storeFile = file("test-signing.jks")
            storePassword = "indoornav-test"
            keyAlias = "indoornav"
            keyPassword = "indoornav-test"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("test")
        }
        release {
            signingConfig = signingConfigs.getByName("test")
        }
    }
}

flutter {
    source = "../.."
}
