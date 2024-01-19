# background_task

## Motivation

Enable developers to continue processing even when the application transitions to the background, we have created a package that allows processing to continue using location updates.This package was created with reference to [background_location](https://pub.dev/packages/background_location).

Can be used when you want to run the program periodically in the background.

- Monitor and notify the distance walked and steps.
- Notification of destination arrival.
- Tracking location information (sending it to a server).

## Usage

```dart
// Monitor notifications of background processes.
// However, Cannot be used while the app is in task kill.
BackgroundTask.instance.stream.listen((event) {
  // Implement the process you want to run in the background.
  // ex) Check health data.
});

// Start background processing with location updates.
await BackgroundTask.instance.start();

// Stop background processing and location updates.
await BackgroundTask.instance.stop();
```

Recommended to use with [permission_handler](https://pub.dev/packages/permission_handler).

```dart
final status = Platform.isIOS
    ? await Permission.locationAlways.request()
    : await Permission.location.request();
if (!status.isGranted) {
  return;
}
await BackgroundTask.instance.start();
```

This is an implementation for receiving updates even when the task is task-killed.

```dart
// Define callback handler at the top level.
@pragma('vm:entry-point')
void backgroundHandler(Location data) {
  // Implement the process you want to run in the background.
  // ex) Check health data.
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundTask.instance.setBackgroundHandler(backgroundHandler); // 👈 Set callback handler.
  runApp(const MyApp());
}
```

To get the latest location information in a task-killed status, set the app to Always.

![ios](./img/ios_location_permission_for_task_kill.png)
![android](./img/android_location_permission_for_task_kill.png)


This is an implementation for when you want to stop using the application when it is killed.

```dart
await BackgroundTask.instance.start(
  isEnabledEvenIfKilled: false,
);
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
<string>Used to monitor location in the background and notify to app.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Used to monitor location in the background and notify to app.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to monitor location in the background and notify to app.</string>
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
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
