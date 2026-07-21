# 0.4.0

- Converted the Android plugin and example project from Groovy Gradle scripts
  to Kotlin DSL.
- Updated the example project to Kotlin 2.2.20 while retaining Flutter 3.44
  compatibility with AGP 9.
- Added iOS `UIScene` lifecycle support and restored persistent background
  location monitoring when a scene connects or enters the background.
- Removed the unused `integration_test` dependency from the example project.

## 0.3.0

- Updated Android builds for Gradle 9.1, AGP 9, Kotlin 2.2, and JVM 17.
- Removed direct Kotlin Gradle Plugin application from the app and plugin.
- Improved Android foreground-service permissions, lifecycle cleanup, and
  background callback delivery.
- Added iOS Swift Package Manager support and improved background Flutter engine
  lifecycle handling.

## 0.2.0+2

Updated README.

## 0.2.0+1

Updated example code and README.

## 0.2.0

- Added parameters and fix Android's foregroundService. [#7](https://github.com/never-inc/flutter_background_task/pull/7).
  - Please add `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>` in AndroidManifest.xml.
- Updated example project by latest flutter version.

## 0.1.3

Bug fix for Android SDK 34.

## 0.1.2

Android Bug fix.

## 0.1.1+1

Updated README.

## 0.1.1

Bug fix.

## 0.1.0+1

Updated README.

## 0.1.0

Enabled to work even if the app task is killed.

## 0.0.8

Fixed Android bug.

## 0.0.7

Fixed LICENCE.

## 0.0.6

Removed permissions from AndroidManifest.xml. Please set permissions. Added to README.

## 0.0.5+1

Updated README.

## 0.0.5

Added DesiredAccuracy for iOS.

## 0.0.4

iOS Bug fixed.

## 0.0.3+1

Updated example.

## 0.0.3

Added isRunning, status.

## 0.0.2

Fixed android permissions.

## 0.0.1+1

Updated document.

## 0.0.1

First release.
