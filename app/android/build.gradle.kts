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

    // Force every Android plugin subproject to compile against SDK 36.
    // Some plugins (e.g. file_picker 8.x) pin an older compileSdk in their own
    // build script, which fails AAR metadata checks when a transitive dep
    // requires 36. afterEvaluate runs after the plugin's script sets its value,
    // so our override wins. Registered before evaluationDependsOn(":app") below
    // so the project is not yet evaluated when we attach the callback.
    // Reflection keeps this independent of the AGP classpath in the root project.
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val cls = androidExt.javaClass
                val byMethod = cls.methods.firstOrNull {
                    it.name == "compileSdkVersion" &&
                        it.parameterCount == 1 &&
                        it.parameterTypes[0] == Int::class.javaPrimitiveType
                }
                if (byMethod != null) {
                    byMethod.invoke(androidExt, 36)
                } else {
                    cls.methods.firstOrNull {
                        it.name == "setCompileSdk" && it.parameterCount == 1
                    }?.invoke(androidExt, 36)
                }
            } catch (_: Exception) {
                // leave the plugin's own compileSdk in place on failure
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
