plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.table_tennis_scoreboard"
    compileSdk = flutter.compileSdkVersion// Replace with your actual compileSdk version

    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.table_tennis_scoreboard"
        minSdk = 21  // Or use what you had earlier
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
