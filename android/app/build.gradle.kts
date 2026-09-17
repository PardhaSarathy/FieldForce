import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key, kept out of the repository.
//
// `android/key.properties` names a keystore file and its passwords and is
// gitignored; create it from key.properties.example when the app is ready to
// go to Play. Without it a release build still works and is signed with the
// debug key — fine for `flutter run --release` and for handing somebody an
// APK, and refused by Play, which is the right way round.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.pharmaconnect.pharmaconnect"

    // Pinned rather than tracking flutter.compileSdkVersion. The installed SDK
    // ships an "android-37.0" platform whose ApiLevel reads "37.0", but Gradle
    // resolves the hash string "android-37" and fails to find it. 36 is the
    // newest platform that is actually installed and resolvable here.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // The application ID is permanent from the first Play upload: changing
        // it afterwards is a different app that installed phones cannot update
        // to. Still the scaffold's, and still to be decided.
        applicationId = "com.pharmaconnect.pharmaconnect"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The upload key when there is one, the debug key otherwise — so a
            // release build never fails for want of a keystore, and never
            // reaches Play signed with the wrong one.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
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
