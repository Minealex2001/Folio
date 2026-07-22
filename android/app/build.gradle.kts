import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties (no versionado, ver .gitignore) trae las credenciales
// del keystore de release. Sin ese archivo, el release cae de nuevo a la
// firma de debug (permite `flutter build` a otros contribuidores sin el keystore).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.minealexgames.folio"
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
        applicationId = "com.minealexgames.folio"
        // ML Kit GenAI Prompt (Gemini Nano) requiere API 26+.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Firma con el keystore de release si android/key.properties existe;
            // si no, cae a la clave de debug (build local sin credenciales de Play).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Suprime warnings de compatibilidad Java 8 que emiten dependencias de terceros
// (como passkeys_doctor) al compilar con JDK moderno.
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
}

flutter {
    source = "../.."
}

dependencies {
    // Gemini Nano on-device via AICore (ML Kit GenAI Prompt API).
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")
}
