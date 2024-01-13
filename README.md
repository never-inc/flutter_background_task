# background_task

## Motivation

Enable developers to continue processing even when the application transitions to the background, we have created a package that allows processing to continue using location updates.This package was created with reference to [background_location](https://pub.dev/packages/background_location).

Can be used when you want to run the program periodically in the background.

- Monitor and notify the distance walked and steps.
- Notification of destination arrival.

## Usage

```dart
// Monitor notifications of background processes.
BackgroundTask.instance.stream.listen((event) {
    // Implement the process you want to run in the background.
    // ex) Check health data.
});

// Start background processing with location updates.
// Android only: Start Foreground service. If you want to show foreground service notifications, please execute a notification permission request before start.
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
