import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The jni package, pulled in transitively, compiles a native library through
// CMake. The linker stamps it with a build-id derived from object data that
// carries the NDK's own install path, and although that path never reaches the
// packaged library, the build-id keeps a trace of it: the same source built
// against an NDK in a different directory produces a library differing in
// exactly those 20 bytes. That is enough to fail F-Droid's check that their
// rebuild matches the published APK.
//
// Dropping the build-id removes the difference at the source, rather than
// requiring every build of this app to put its NDK in the same place.
// https://f-droid.org/docs/Reproducible_Builds/
subprojects {
    plugins.withId("com.android.library") {
        if (name == "jni") {
            extensions.configure<LibraryExtension>("android") {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments +=
                                "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
                        }
                    }
                }
            }
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
