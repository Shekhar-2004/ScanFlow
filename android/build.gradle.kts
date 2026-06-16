allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
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
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.github.yalantis:ucrop")).using(module("io.github.lucksiege:ucrop:v3.11.3"))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
