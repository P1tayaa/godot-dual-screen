plugins {
    id("com.android.library")
}

android {
    namespace = "dev.p1tayaa.dualscreen"
    compileSdk = 36 // match the Godot 4.7 Android build template (android/build/config.gradle)

    defaultConfig {
        minSdk = 24 // Godot 4.7 minimum
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Provided by the Godot app at runtime.
    compileOnly("org.godotengine:godot:4.7.2.stable")
}

// ./gradlew copyToAddon: builds both AARs and puts them where the Godot export plugin looks.
tasks.register<Copy>("copyToAddon") {
    dependsOn("assembleDebug", "assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("plugin-debug.aar", "plugin-release.aar")
    rename("plugin-(.*)\\.aar", "dual-screen-android-$1.aar")
    into(rootProject.layout.projectDirectory.dir("../bin"))
}
