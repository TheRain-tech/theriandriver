import java.util.Properties

val envProperties = Properties().apply {
    val envFile = rootProject.file("../.env")
    if (envFile.exists()) {
        envFile.inputStream().use { load(it) }
    }
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val googleMapsApiKey =
    localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: envProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""

val keyProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

fun signingProperty(propertyName: String, envName: String): String? =
    keyProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envName)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingProperty("storeFile", "THERAIN_DRIVER_STORE_FILE")
val releaseStorePassword =
    signingProperty("storePassword", "THERAIN_DRIVER_STORE_PASSWORD")
val releaseKeyAlias = signingProperty("keyAlias", "THERAIN_DRIVER_KEY_ALIAS")
val releaseKeyPassword =
    signingProperty("keyPassword", "THERAIN_DRIVER_KEY_PASSWORD")
val releaseSigningConfigured =
    !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.therain.driver"
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
        applicationId = "com.therain.driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.name.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !releaseSigningConfigured) {
        throw GradleException(
            "Release signing is not configured. Create android/key.properties " +
                "or set THERAIN_DRIVER_STORE_FILE, THERAIN_DRIVER_STORE_PASSWORD, " +
                "THERAIN_DRIVER_KEY_ALIAS, and THERAIN_DRIVER_KEY_PASSWORD."
        )
    }
    if (releaseRequested && googleMapsApiKey.isBlank()) {
        throw GradleException(
            "GOOGLE_MAPS_API_KEY is required for release builds."
        )
    }
}
