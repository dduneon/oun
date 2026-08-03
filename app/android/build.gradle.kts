allprojects {
    repositories {
        google()
        mavenCentral()
        // Unity export가 함께 내보내는 AAR들(unityLibrary/libs)을 찾게 한다.
        flatDir {
            dirs(file("${project(":unityLibrary").projectDir}/libs"))
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
