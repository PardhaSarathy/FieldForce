allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins declare their own compileSdk, and at least one asks for 37 — which
// this SDK installation cannot resolve: it ships an "android-37.0" platform
// whose ApiLevel reads "37.0", while Gradle looks up the hash string
// "android-37". Force every Android module onto the pinned level so the build
// does not depend on which platforms happen to be installed.
//
// This must run before the evaluationDependsOn block below, which evaluates
// the subprojects and would make a later afterEvaluate hook illegal.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}
