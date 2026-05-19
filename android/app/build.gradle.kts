plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dev.koru"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dev.koru"
        minSdk = 28
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: sostituire con signing config di release.
            signingConfig = signingConfigs.getByName("debug")
            // R8 e' attivato di default su release dal Flutter Gradle Plugin
            // (AGP 8+). proguard-rules.pro contiene -dontwarn per annotation
            // di compile-time referenziate da Tink ma non incluse nell'APK
            // (senza, il task minifyReleaseWithR8 falliva con "Missing class
            // com.google.errorprone.annotations.* / javax.annotation.*").
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    // Jetpack Compose per overlay Kotlin-native (Step 6+).
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.activity:activity-compose:1.9.3")

    // Android core
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-service:2.8.7")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    // Keystore-backed encrypted preferences per strict mode mask, backdoor code
    // e counter di lockout. Necessario perché i file plain in filesDir sono
    // letti/scritti senza integrità (un utente con accesso al filesystem può
    // azzerare la mask). EncryptedSharedPreferences usa AES-256 GCM con chiave
    // master dal Keystore hardware (StrongBox quando disponibile).
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // ─── Unit testing ─────────────────────────────────────────────────────
    // JUnit 4 + MockK + Truth + Robolectric per i test JVM (src/test/...).
    // Robolectric per i test che toccano Android Context, SharedPreferences,
    // resources, etc. — gira in JVM senza emulator.
    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("com.google.truth:truth:1.4.4")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("androidx.test:core-ktx:1.6.1")
    testImplementation("androidx.test.ext:junit:1.2.1")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    testImplementation("org.json:json:20240303")
}

flutter {
    source = "../.."
}
