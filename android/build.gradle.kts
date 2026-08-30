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

subprojects {
    fun applyNamespace(p: Project) {
        val androidExt = p.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val compileSdkVersionMethod = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                compileSdkVersionMethod.invoke(androidExt, 36)
            } catch (_: Exception) {}

            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(androidExt)
                if (namespace == null) {
                    val ns = if (p.name == "blue_thermal_printer") "id.kakzaki.blue_thermal_printer" else "com.example." + p.name.replace("-", "_")
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(androidExt, ns)
                }
            } catch (_: Exception) {}
        }
    }

    if (state.executed) {
        applyNamespace(this)
    } else {
        afterEvaluate {
            applyNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
