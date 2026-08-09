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
// Flutter plugins each pin their own compileSdk, and several of them are years
// behind what their own dependencies now require. That makes the build fail on
// the plugin rather than on anything here, and there is nothing to edit in our
// own source that fixes it. Compiling every module against the same recent sdk
// is the usual answer: it changes which apis are visible at compile time and
// nothing about runtime behaviour, which is targetSdk's job.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            val setCompileSdk = android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            setCompileSdk?.invoke(android, 37)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
