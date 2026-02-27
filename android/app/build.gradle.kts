plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sam_jas_academy"
    
    // Set to 36 to satisfy new plugin requirements
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // REQUIRED for flutter_local_notifications and modern WebView support
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.sam_jas_academy"
        
        // Forced to 21 to ensure WebView has modern security features for Zoom
        minSdk = flutter.minSdkVersion 
        
        targetSdk = 36 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true 
        ndk {
        abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
         }
    }

    buildTypes {
        getByName("release") {
            // Keep false for now to prevent R8 from stripping Zoom JS bridge
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // This library handles Java 8+ features on older phones
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
    // Explicit multidex dependency to prevent crashes on app start/navigation
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.webkit:webkit:1.10.0") // Add this line
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
}
