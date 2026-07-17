/**
Copyright [2024] [Never Inc.]
Copyright [2019] [Ali Almoullim]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import CoreLocation
import Flutter
import UIKit

public class BackgroundTaskPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    private static func makeDispatchEngine() -> FlutterEngine {
        FlutterEngine(
            name: Bundle.main.bundleIdentifier ?? "background_task",
            project: nil,
            allowHeadlessExecution: true
        )
    }

    public static var dispatchEngine = makeDispatchEngine()
    public static var onRegisterDispatchEngine: (() -> Void)?

    private static var isRegisteredDispatchEngine = false
    private static var isDispatchChannelReady = false
    private static var pendingBackgroundUpdates: [[String: Any]] = []
    private static let maxPendingBackgroundUpdates = 100

    private static var locationManager: CLLocationManager?
    private static var channel: FlutterMethodChannel?
    private static var bgEventChannel: FlutterEventChannel?
    private static var statusEventChannel: FlutterEventChannel?
    private static var isRunning = false

    private static var dispatchChannel: FlutterMethodChannel?
    private static var dispatcherRawHandle: Int?
    private static var handlerRawHandle: Int?

    private var isEnabledEvenIfKilled: Bool {
        UserDefaultsRepository.instance.fetchIsEnabledEvenIfKilled()
    }

    enum DesiredAccuracy: String {
        case reduced
        case bestForNavigation
        case best
        case nearestTenMeters
        case hundredMeters
        case kilometer
        case threeKilometers

        var kCLLocation: CLLocationAccuracy {
            switch self {
            case .reduced:
                if #available(iOS 14.0, *) {
                    return kCLLocationAccuracyReduced
                }
                return kCLLocationAccuracyThreeKilometers
            case .bestForNavigation:
                return kCLLocationAccuracyBestForNavigation
            case .best:
                return kCLLocationAccuracyBest
            case .nearestTenMeters:
                return kCLLocationAccuracyNearestTenMeters
            case .hundredMeters:
                return kCLLocationAccuracyHundredMeters
            case .kilometer:
                return kCLLocationAccuracyKilometer
            case .threeKilometers:
                return kCLLocationAccuracyThreeKilometers
            }
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BackgroundTaskPlugin()
        registrar.addApplicationDelegate(instance)

        let channel = FlutterMethodChannel(
            name: ChannelName.methods.value,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
        BackgroundTaskPlugin.channel = channel

        let bgEventChannel = FlutterEventChannel(
            name: ChannelName.bgEvent.value,
            binaryMessenger: registrar.messenger()
        )
        bgEventChannel.setStreamHandler(BgEventStreamHandler())
        BackgroundTaskPlugin.bgEventChannel = bgEventChannel

        let statusEventChannel = FlutterEventChannel(
            name: ChannelName.statusEvent.value,
            binaryMessenger: registrar.messenger()
        )
        statusEventChannel.setStreamHandler(StatusEventStreamHandler())
        BackgroundTaskPlugin.statusEventChannel = statusEventChannel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start_background_task":
            startBackgroundTask(call, result: result)
        case "stop_background_task":
            stopBackgroundTask()
            result(true)
        case "is_running_background_task":
            result(Self.isRunning)
        case "set_background_handler":
            let args = call.arguments as? [String: Any]
            Self.dispatcherRawHandle =
                Self.intValue(args?["callbackDispatcherRawHandle"])
            Self.handlerRawHandle =
                Self.intValue(args?["callbackHandlerRawHandle"])
            debugPrint("registered \(String(describing: args))")
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
    ) -> Bool {
        guard launchOptions[UIApplication.LaunchOptionsKey.location] != nil else {
            return true
        }

        registerDispatchEngine()
        let (distanceFilter, desiredAccuracy, pausesAutomatically) =
            UserDefaultsRepository.instance.fetch()
        startLocationManager(
            distanceFilter: distanceFilter,
            desiredAccuracy: desiredAccuracy,
            pausesLocationUpdatesAutomatically: pausesAutomatically,
            monitorSignificantChanges: true,
            requestAuthorization: false
        )
        return true
    }

    public func applicationDidEnterBackground(_ application: UIApplication) {
        if isEnabledEvenIfKilled {
            Self.locationManager?.startMonitoringSignificantLocationChanges()
        }
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        if isEnabledEvenIfKilled {
            Self.locationManager?.startMonitoringSignificantLocationChanges()
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        publishAuthorizationStatus(manager.authorizationStatus)
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        if #available(iOS 14.0, *) {
            return
        }
        publishAuthorizationStatus(status)
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let lastLocation = locations.last else {
            return
        }

        let lat = lastLocation.coordinate.latitude
        let lng = lastLocation.coordinate.longitude
        let location: [String: Double] = ["lat": lat, "lng": lng]

        BgEventStreamHandler.eventSink?(location)
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.updated(
                message: "lat:\(lat) lng:\(lng)"
            ).value
        )

        let callbackHandlerRawHandle =
            UserDefaultsRepository.instance.fetchCallbackHandlerRawHandle()
        guard callbackHandlerRawHandle != 0 else {
            return
        }
        dispatchBackgroundUpdate([
            "callbackHandlerRawHandle": callbackHandlerRawHandle,
            "lat": lat,
            "lng": lng,
        ])
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("didFailWithError: \(error)")
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.error(
                message: error.localizedDescription
            ).value
        )
    }

    private func startBackgroundTask(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let args = call.arguments as? [String: Any]
        let distanceFilter = (args?["distanceFilter"] as? Double) ?? 0
        let pausesAutomatically =
            (args?["pausesLocationUpdatesAutomatically"] as? Bool) ?? false
        let desiredAccuracy =
            (args?["iOSDesiredAccuracy"] as? String)
                .flatMap(DesiredAccuracy.init(rawValue:)) ?? .reduced
        let isEnabledEvenIfKilled =
            (args?["isEnabledEvenIfKilled"] as? Bool) ?? false

        let repository = UserDefaultsRepository.instance
        repository.removeRawHandle()
        if let dispatcherRawHandle = Self.dispatcherRawHandle,
           let handlerRawHandle = Self.handlerRawHandle {
            repository.save(
                callbackDispatcherRawHandle: dispatcherRawHandle,
                callbackHandlerRawHandle: handlerRawHandle
            )
        }
        repository.save(
            distanceFilter: distanceFilter,
            desiredAccuracy: desiredAccuracy,
            pausesLocationUpdatesAutomatically: pausesAutomatically
        )
        repository.saveIsEnabledEvenIfKilled(isEnabledEvenIfKilled)

        registerDispatchEngine()
        startLocationManager(
            distanceFilter: distanceFilter,
            desiredAccuracy: desiredAccuracy,
            pausesLocationUpdatesAutomatically: pausesAutomatically,
            monitorSignificantChanges: isEnabledEvenIfKilled,
            requestAuthorization: true
        )
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.start(
                message: "\(desiredAccuracy)"
            ).value
        )
        result(true)
    }

    private func startLocationManager(
        distanceFilter: Double,
        desiredAccuracy: DesiredAccuracy,
        pausesLocationUpdatesAutomatically: Bool,
        monitorSignificantChanges: Bool,
        requestAuthorization: Bool
    ) {
        stopLocationManager()

        let locationManager = CLLocationManager()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically =
            pausesLocationUpdatesAutomatically
        locationManager.desiredAccuracy = desiredAccuracy.kCLLocation
        locationManager.distanceFilter = distanceFilter
        locationManager.activityType = .fitness
        locationManager.delegate = self
        if requestAuthorization {
            locationManager.requestAlwaysAuthorization()
        }
        if monitorSignificantChanges {
            locationManager.startMonitoringSignificantLocationChanges()
        }
        locationManager.startUpdatingLocation()

        Self.locationManager = locationManager
        Self.isRunning = true
    }

    private func stopBackgroundTask() {
        UserDefaultsRepository.instance.saveIsEnabledEvenIfKilled(false)
        stopLocationManager()
        cleanupDispatchEngine()
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.stop.value
        )
    }

    private func stopLocationManager() {
        Self.locationManager?.stopMonitoringSignificantLocationChanges()
        Self.locationManager?.stopUpdatingLocation()
        Self.locationManager?.delegate = nil
        Self.locationManager = nil
        Self.isRunning = false
    }

    private func publishAuthorizationStatus(_ status: CLAuthorizationStatus) {
        let isEnabled = status == .authorizedAlways || status == .authorizedWhenInUse
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.permission(
                message: isEnabled ? "enabled" : "disabled"
            ).value
        )
    }

    private func registerDispatchEngine() {
        if Self.isRegisteredDispatchEngine {
            return
        }

        let handle =
            UserDefaultsRepository.instance.fetchCallbackDispatcherRawHandle()
        guard handle != 0,
              let info = FlutterCallbackCache.lookupCallbackInformation(Int64(handle))
        else {
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.error(
                    message: "Background callback dispatcher could not be resolved."
                ).value
            )
            return
        }

        guard Self.dispatchEngine.run(
            withEntrypoint: info.callbackName,
            libraryURI: info.callbackLibraryPath
        ) else {
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.error(
                    message: "Background Flutter engine could not be started."
                ).value
            )
            return
        }

        Self.isRegisteredDispatchEngine = true
        Self.isDispatchChannelReady = false
        Self.onRegisterDispatchEngine?()

        let dispatchChannel = FlutterMethodChannel(
            name: ChannelName.methods.value,
            binaryMessenger: Self.dispatchEngine.binaryMessenger
        )
        dispatchChannel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "callback_channel_initialized" else {
                result(FlutterMethodNotImplemented)
                return
            }

            Self.isDispatchChannelReady = true
            dispatchChannel.invokeMethod(
                "notify_callback_dispatcher",
                arguments: nil
            )
            self?.flushPendingBackgroundUpdates()
            result(true)
        }
        Self.dispatchChannel = dispatchChannel
    }

    private func dispatchBackgroundUpdate(_ data: [String: Any]) {
        if Self.isDispatchChannelReady, let dispatchChannel = Self.dispatchChannel {
            dispatchChannel.invokeMethod("background_handler", arguments: data)
            return
        }

        if Self.pendingBackgroundUpdates.count >= Self.maxPendingBackgroundUpdates {
            Self.pendingBackgroundUpdates.removeFirst()
        }
        Self.pendingBackgroundUpdates.append(data)
    }

    private func flushPendingBackgroundUpdates() {
        guard let dispatchChannel = Self.dispatchChannel else {
            return
        }
        for data in Self.pendingBackgroundUpdates {
            dispatchChannel.invokeMethod("background_handler", arguments: data)
        }
        Self.pendingBackgroundUpdates.removeAll(keepingCapacity: false)
    }

    private func cleanupDispatchEngine() {
        Self.dispatchChannel?.setMethodCallHandler(nil)
        Self.dispatchChannel = nil
        Self.isDispatchChannelReady = false
        Self.pendingBackgroundUpdates.removeAll(keepingCapacity: false)

        if Self.isRegisteredDispatchEngine {
            Self.dispatchEngine.destroyContext()
            Self.dispatchEngine = Self.makeDispatchEngine()
            Self.isRegisteredDispatchEngine = false
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }
}
