import java.util.Properties

// Release signing material, kept out of the repository. Create
// android/key.properties (gitignored) from key.properties.example to sign a
// release build. When it is absent - a fresh clone, CI, or the F-Droid builder,
// which signs with its own key - the release build falls back to the debug key
// so `flutter build` still works.
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
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
