pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = java.io.File(rootDir, "local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val flutterSdk = properties.getProperty("flutter.sdk")
        assert(flutterSdk != null) { "flutter.sdk not set in local.properties" }
        flutterSdk
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // Updated Kotlin plugin to 2.3.10 to match installed stdlib metadata
    id("org.jetbrains.kotlin.android") version "2.3.10" apply false
    id("com.google.gms.google-services") version "4.4.1" apply false
}

include(":app")