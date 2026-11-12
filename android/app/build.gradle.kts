import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de produção: lida de android/key.properties (fora do Git) ou das
// variáveis de ambiente ALL_* (CI). Sem ela, o release sai assinado com a
// chave de debug, só para teste. Ver docs/PUBLICACAO.md.
val releaseKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
    System.getenv("ALL_STORE_FILE")?.let { setProperty("storeFile", it) }
    System.getenv("ALL_STORE_PASSWORD")?.let { setProperty("storePassword", it) }
    System.getenv("ALL_KEY_ALIAS")?.let { setProperty("keyAlias", it) }
    System.getenv("ALL_KEY_PASSWORD")?.let { setProperty("keyPassword", it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseKey.getProperty(it).isNullOrBlank() }

android {
    namespace = "io.github.lucasbritosilva.aplicativoall"
    // flutter_local_notifications 23 e permission_handler 13 exigem compileSdk 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necessário para o agendamento de notificações (flutter_local_notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador público do app. Não mude: é ele que permite atualizar por cima.
        applicationId = "io.github.lucasbritosilva.aplicativoall"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
