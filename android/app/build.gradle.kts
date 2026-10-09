import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.isign.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.isign.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    // Load signing config from key.properties (gitignored) or environment variables
    val keyPropsFile = rootProject.file("key.properties")
    val keyProps = Properties()
    val hasKeyProps = keyPropsFile.exists()
    if (hasKeyProps) {
        keyProps.load(FileInputStream(keyPropsFile))
    }

    signingConfigs {
        create("release") {
            storeFile = if (hasKeyProps) file(keyProps["storeFile"] as String) else file("key.jks")
            storePassword = if (hasKeyProps) keyProps["storePassword"] as String else (System.getenv("KEYSTORE_PASSWORD") ?: "isign123")
            keyAlias = if (hasKeyProps) keyProps["keyAlias"] as String else (System.getenv("KEY_ALIAS") ?: "isign")
            keyPassword = if (hasKeyProps) keyProps["keyPassword"] as String else (System.getenv("KEY_PASSWORD") ?: "isign123")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// Workaround: copy APK to project-level build dir where Flutter expects it
val projectBuildDir = rootProject.projectDir.parentFile.resolve("build")
tasks.whenTaskAdded {
    if (name.startsWith("package") && (name.endsWith("Debug") || name.endsWith("Release"))) {
        doLast {
            val buildType = if (name.endsWith("Debug")) "debug" else "release"
            val src = layout.buildDirectory.file("outputs/apk/$buildType/app-$buildType.apk").get().asFile
            if (src.exists()) {
                val dstDir = projectBuildDir.resolve("app/outputs/flutter-apk")
                dstDir.mkdirs()
                src.copyTo(dstDir.resolve("app-$buildType.apk"), overwrite = true)
            }
        }
    }
}