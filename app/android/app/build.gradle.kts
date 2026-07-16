import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from android/key.properties (git-ignored, never
// committed). When it's absent — CI, or a dev who only builds debug — release
// APKs fall back to the debug keystore so `flutter run --release` still works.
// Store bundles (bundleRelease) are the exception: they must never ship
// debug-signed, so those fail closed below when key.properties is missing.
// See android/key.properties.example.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "pro.dotslash.ava"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pro.dotslash.ava"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Distribution channels. Same applicationId on purpose: play and cn have
    // always shipped under one package name and upgrades must keep working
    // in both directions. Play-only dependencies (ads/billing/sign-in) hook
    // into the `play` flavor; the cn APK must never contain them.
    flavorDimensions += "channel"
    productFlavors {
        create("play") { dimension = "channel" }
        create("cn") { dimension = "channel" }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String).let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real upload key when key.properties is present; otherwise
            // fall back to debug signing so release builds still run locally/CI.
            signingConfig = if (hasReleaseSigning)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // Keep rules for reflection-based libraries (ML Kit barcode) that
            // R8 full mode otherwise breaks in release builds.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fail closed: a Play bundle built without the upload key would be silently
// debug-signed and rejected (or worse, archived as a broken release artifact).
gradle.taskGraph.whenReady {
    val aabTask = Regex("^bundle\\w*Release$") // bundleRelease, bundle<Flavor>Release
    if (!hasReleaseSigning &&
        allTasks.any { it.project == project && aabTask.matches(it.name) }
    ) {
        throw GradleException(
            "Release bundle requested but android/key.properties is missing — " +
                "the AAB would be debug-signed. Provide the upload key " +
                "(see android/key.properties.example) or build a debug bundle instead."
        )
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
