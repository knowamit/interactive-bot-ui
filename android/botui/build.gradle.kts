plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.plugin.compose")
    id("maven-publish")
}

android {
    namespace = "dev.botui"
    compileSdk = 35
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { compose = true }
    publishing { singleVariant("release") { withSourcesJar() } }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.11.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    testImplementation("junit:junit:4.13.2")
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                groupId = "com.github.knowamit"
                artifactId = "interactive-bot-ui"
                version = "0.1.0"
                pom {
                    name.set("Interactive Bot UI")
                    description.set("Animated, touch-reactive bot avatar for Jetpack Compose.")
                    url.set("https://github.com/knowamit/interactive-bot-ui")
                    licenses { license { name.set("MIT License"); url.set("https://opensource.org/licenses/MIT") } }
                }
            }
        }
    }
}
