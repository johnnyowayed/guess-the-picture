allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val androidBuildRoot = providers.provider {
    file("${System.getProperty("java.io.tmpdir")}/guess_the_picture_android_build")
}
val newBuildDir = rootProject.layout.dir(androidBuildRoot)
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    project.layout.buildDirectory.set(newBuildDir.map { it.dir(project.name) })
}
subprojects {
    project.evaluationDependsOn(":app")
}

val flutterExpectedBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
val syncFlutterDebugOutputs = tasks.register<Copy>("syncFlutterDebugOutputs") {
    from(newBuildDir.map { it.dir("app/outputs/flutter-apk") })
    into(flutterExpectedBuildDir.dir("app/outputs/flutter-apk"))
}

val syncFlutterReleaseOutputs = tasks.register<Copy>("syncFlutterReleaseOutputs") {
    from(newBuildDir.map { it.dir("app/outputs/flutter-apk") })
    into(flutterExpectedBuildDir.dir("app/outputs/flutter-apk"))
}

val syncFlutterBundleOutputs = tasks.register<Copy>("syncFlutterBundleOutputs") {
    from(newBuildDir.map { it.dir("app/outputs/bundle") })
    into(flutterExpectedBuildDir.dir("app/outputs/bundle"))
}

gradle.projectsEvaluated {
    rootProject.subprojects
        .firstOrNull { it.path == ":app" }
        ?.tasks
        ?.matching { it.name == "assembleDebug" }
        ?.configureEach {
            finalizedBy(syncFlutterDebugOutputs)
        }

    rootProject.subprojects
        .firstOrNull { it.path == ":app" }
        ?.tasks
        ?.matching { it.name == "assembleRelease" }
        ?.configureEach {
            finalizedBy(syncFlutterReleaseOutputs)
        }

    rootProject.subprojects
        .firstOrNull { it.path == ":app" }
        ?.tasks
        ?.matching { it.name == "bundleRelease" }
        ?.configureEach {
            finalizedBy(syncFlutterBundleOutputs)
        }
}

tasks.register<Delete>("clean") {
    delete(newBuildDir)
}
