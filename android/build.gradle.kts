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
subprojects {
    project.evaluationDependsOn(":app")
}

// Some older plugins (e.g. file_picker 3.0.4) predate AGP's namespace
// requirement and don't declare one in their android/build.gradle. Fall back
// to the plugin's Gradle group (which Flutter's plugin loader already sets
// to the plugin's Android package) so those plugins keep building under
// AGP 8+ without needing a dependency bump. No-op for any subproject that
// already declares its own namespace.
subprojects {
    fun applyFallbackNamespace() {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.BaseExtension) {
            if (androidExtension.namespace == null) {
                androidExtension.namespace = project.group.toString()
            }
        }
    }
    if (project.state.executed) {
        applyFallbackNamespace()
    } else {
        afterEvaluate { applyFallbackNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
