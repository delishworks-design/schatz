plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.schatz.production"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.schatz.production"
        minSdk = 26
        targetSdk = 34
        versionCode = 12
        versionName = "12.0-production"
        ndk { abiFilters += listOf("arm64-v8a","armeabi-v7a") }
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.material.ExperimentalMaterialApi",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi",
            "-opt-in=androidx.compose.animation.ExperimentalAnimationApi"
        )
    }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.8" }
    packaging { jniLibs { useLegacyPackaging = true } }
    testOptions { unitTests { isIncludeAndroidResources = true; isReturnDefaultValues = true } }
}
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.compose.ui:ui:1.6.1")
    implementation("androidx.compose.material3:material3:1.1.2")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.navigation:navigation-compose:2.7.6")
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("androidx.biometric:biometric:1.1.0")
    // Chat media: Coil renders received photos straight from the downloaded local path, and
    // Media3/ExoPlayer is the video + audio player for bubbles and the full-screen viewer.
    implementation("io.coil-kt:coil-compose:2.5.0")
    implementation("androidx.media3:media3-exoplayer:1.3.1")
    implementation("androidx.media3:media3-ui:1.3.1")
    implementation(files("libs/tdlib.jar"))

    testImplementation("junit:junit:4.13.2")
    // A plain JVM mock is enough here: EnhancedVaultManager only ever touches
    // Context.getFilesDir()/getCacheDir(). Robolectric is deliberately not used because its
    // Conscrypt JNI is glibc-linked and cannot be dlopen'd on this aarch64/bionic host.
    testImplementation("org.mockito:mockito-core:5.11.0")
}
