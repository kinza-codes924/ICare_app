allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Fix for older Flutter plugins (e.g. zego_zim 2.16.0) that predate AGP 8's
// requirement that every Android module declare a `namespace`. Those plugins
// still only set the legacy `package` attribute in their AndroidManifest.xml,
// which AGP 8 rejects. We back-fill the namespace from that package for any
// library subproject that lacks one, so the release build stops failing with
// "Namespace not specified".
//
// MUST run before the evaluationDependsOn(":app") block below — that forces
// every subproject to fully evaluate, after which the `android` extension is
// locked and an afterEvaluate hook is too late ("project is already
// evaluated"). Hooking plugins.withId(...) sets the namespace the instant the
// AGP plugin registers its extension, well before evaluation completes.
// Reflection avoids needing AGP classes on the root project's classpath.
fun Project.backfillNamespace() {
    val androidExtension = extensions.findByName("android") ?: return
    try {
        val current = androidExtension.javaClass.getMethod("getNamespace")
            .invoke(androidExtension) as String?
        if (current == null) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val pkg = Regex("package=\"(.+?)\"")
                    .find(manifestFile.readText())
                    ?.groupValues?.get(1)
                if (pkg != null) {
                    androidExtension.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(androidExtension, pkg)
                }
            }
        }
    } catch (_: Exception) {
        // Not an Android library / no namespace API — nothing to fix.
    }
}

subprojects {
    plugins.withId("com.android.library") { backfillNamespace() }
    plugins.withId("com.android.application") { backfillNamespace() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
