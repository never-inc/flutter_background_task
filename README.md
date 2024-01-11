# flutter_background_task

## Motivation

Enable developers to continue processing even when the application transitions to the background, we have created a package that allows processing to continue using location updates.This package was created with reference to [background_location](https://pub.dev/packages/background_location).

## Usage

```dart
// Monitor notifications of background processes.
BackgroundTask.instance.stream.listen((_) {
    // Implement the process you want to run in the background.
});

// Start background processing with location updates.
// Android only: Start Foreground service. If you want to show foreground service notifications, please execute a notification permission request before start.
await BackgroundTask.instance.start();

// Stop background processing and location updates.
await BackgroundTask.instance.stop();
```

### Setup

pubspec.yaml

```yaml
dependencies:
  background_task:
```

iOS: Info.plist

```text
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location.</string>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>location</string>
</array>
```

Android: AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/> 
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<!-- option -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
