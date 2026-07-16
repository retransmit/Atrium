import java.util.Properties

// Release signing material, kept out of the repository. Create
// android/key.properties (gitignored) from key.properties.example to sign a
// release build.
//
// When it is absent the release build is left UNSIGNED, rather than falling
// back to the debug key. F-Droid verifies a release by copying the signature
// off the published APK onto its own build of the same source, which only
// works if its build carries no signature of its own. An unsigned APK cannot
// be installed, so `flutter run --release` needs key.properties present.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseSigning = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // Required for the top-level kotlin { compilerOptions } block below;
    // android.builtInKotlin is off, so nothing else applies Kotlin.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.atrium"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The Android Gradle Plugin otherwise writes an encrypted list of the
    // dependency tree into the APK signing block, for Google Play Console to
    // read. Nothing here is ever uploaded to Play, no build reads it back, and
    // F-Droid refuses to publish an APK carrying an opaque blob it cannot
    // inspect.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    defaultConfig {
        applicationId = "app.atrium"
        // local_auth + flutter_secure_storage need API 23+ (BiometricPrompt,
        // EncryptedSharedPreferences). Floor at 23 regardless of Flutter's
        // default.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Dynamic app label based on project property appName (defaults to "Atrium")
        val appNameProp = if (project.hasProperty("appName")) {
            project.property("appName") as String
        } else {
            "Atrium"
        }
        manifestPlaceholders["appName"] = appNameProp
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                // A relative storeFile resolves against the android/ directory,
                // next to key.properties. An absolute path outside the working
                // tree is safer and is what the example suggests.
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // No signing config at all leaves the APK unsigned. A config
            // carrying a null storeFile is rejected outright by the Android
            // Gradle Plugin, so the absence has to be expressed here.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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
