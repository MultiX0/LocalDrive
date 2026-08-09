import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.localdrive"
    // pinned rather than taken from flutter.compileSdkVersion because
    // receive_sharing_intent is built against 37 and the build fails if we
    // compile against anything lower. compiling against a newer sdk does not
    // change runtime behaviour, targetSdk does, and that stays where it is.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time, which minSdk 24 does not
        // have. desugaring backports it instead of raising the floor.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "app.localdrive"
        // the foreground service type declaration this app relies on is
        // Android 14 API, and drift's sqlite bundle wants a modern floor anyway
        minSdk = 24
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing comes from android/key.properties, which is not in the
    // repository. CI writes it from secrets before building.
    //
    // Falling back to the debug key when it is absent keeps `flutter build apk
    // --release` working locally, but a debug signed apk must never be
    // published: the debug keystore is shared by every Android install on
    // earth, so anyone can sign an update to it. Worse, the signing key cannot
    // change later without every user uninstalling first and losing their
    // data, so shipping one release with the wrong key is permanent.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseKey = keystorePropertiesFile.exists()
    if (hasReleaseKey) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "No android/key.properties found. Signing with the debug key: " +
                        "fine for local testing, never for a published release."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // the foreground service notification, and the retry that wakes the app
    // once the network comes back
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
