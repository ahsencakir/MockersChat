plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services eklendi
    id("com.google.gms.google-services")
}

android {
    ndkVersion = "27.0.12077973"
    namespace = "com.example.mockers_chat"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
      isCoreLibraryDesugaringEnabled = true;
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.mockers_chat2"
        minSdk = 26   // Bunu güncelle
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BoM ekleniyor
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // 🔥 Core Library Desugaring için eklendi!
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Firebase Analytics ekleniyor
    implementation("com.google.firebase:firebase-analytics")

    // Diğer Firebase SDK'ları ihtiyacına göre
    // örneğin:
    // implementation("com.google.firebase:firebase-firestore")
}


// Google Services JSON dosyasını işlemek için gerekli
apply(plugin = "com.google.gms.google-services")
