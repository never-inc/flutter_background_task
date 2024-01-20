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

import Flutter
import UIKit
import CoreLocation

public class BackgroundTaskPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    public static let dispatchEngine: FlutterEngine = FlutterEngine(
        name: Bundle.main.bundleIdentifier ?? "background_task",
        project: nil,
        allowHeadlessExecution: true
    )
    public static var onRegisterDispatchEngine: (() -> Void)?
    static var isRegisteredDispatchEngine = false
    
    static var locationManager: CLLocationManager?
    static var channel: FlutterMethodChannel?
    static var isRunning = false
    
    static var dispatchChannel: FlutterMethodChannel?
    static var dispatcherRawHandle: Int?
    static var handlerRawHandle: Int?
    
    private var isEnabledEvenIfKilled: Bool {
        return UserDefaultsRepository.instance.fetchIsEnabledEvenIfKilled()
    }
    
    enum DesiredAccuracy: String {
        case reduced = "reduced"
        case bestForNavigation = "bestForNavigation"
        case best = "best"
        case nearestTenMeters = "nearestTenMeters"
        case hundredMeters = "hundredMeters"
        case kilometer = "kilometer"
        case threeKilometers = "threeKilometers"
        var kCLLocation: CLLocationAccuracy {
            switch (self) {
            case .reduced:
                if #available(iOS 14.0, *) {
                    return kCLLocationAccuracyReduced
                } else {
                    return kCLLocationAccuracyThreeKilometers
                }
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
        
        let channel = FlutterMethodChannel(name: "com.neverjp.background_task/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        channel.setMethodCallHandler(instance.handle)
        BackgroundTaskPlugin.channel = channel
        
        let bgEventChannel = FlutterEventChannel(name: "com.neverjp.background_task/bgEvent", binaryMessenger: registrar.messenger())
        bgEventChannel.setStreamHandler(BgEventStreamHandler())
        
        let statusEventChannel = FlutterEventChannel(name: "com.neverjp.background_task/statusEvent", binaryMessenger: registrar.messenger())
        statusEventChannel.setStreamHandler(StatusEventStreamHandler())
    
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "start_background_task") {
            let args = call.arguments as? Dictionary<String, Any>
            let distanceFilter = (args?["distanceFilter"] as? Double) ?? 0
            let desiredAccuracy: DesiredAccuracy
            if let value = args?["iOSDesiredAccuracy"] as? String, let type = DesiredAccuracy(rawValue: value) {
                desiredAccuracy = type
            } else {
                desiredAccuracy = .reduced
            }
            let isEnabledEvenIfKilled = (args?["isEnabledEvenIfKilled"] as? Bool) ?? false
            
            let userDefaultsRepository = UserDefaultsRepository.instance
            userDefaultsRepository.removeRawHandle()
            if let dispatcherRawHandle = Self.dispatcherRawHandle, let handlerRawHandle = Self.handlerRawHandle {
                userDefaultsRepository.save(
                    callbackDispatcherRawHandle: dispatcherRawHandle,
                    callbackHandlerRawHandle: handlerRawHandle
                )
            }
            userDefaultsRepository.save(
                distanceFilter: distanceFilter,
                desiredAccuracy: desiredAccuracy
            )
            userDefaultsRepository.saveIsEnabledEvenIfKilled(isEnabledEvenIfKilled)
            
            registerDispatchEngine()
          
            let locationManager = CLLocationManager()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.desiredAccuracy = desiredAccuracy.kCLLocation
            locationManager.distanceFilter = distanceFilter
            locationManager.delegate = self
            Self.locationManager = locationManager
            Self.locationManager?.requestAlwaysAuthorization()
            if (isEnabledEvenIfKilled) {
                Self.locationManager?.startMonitoringSignificantLocationChanges()
            }
            Self.locationManager?.startUpdatingLocation()
            Self.isRunning = true
            
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.start(message: "\(desiredAccuracy)").value
            )
            result(true)
        } else if (call.method == "stop_background_task") {
            if isEnabledEvenIfKilled {
                Self.locationManager?.stopMonitoringSignificantLocationChanges()
            }
            UserDefaultsRepository.instance.saveIsEnabledEvenIfKilled(false)
            Self.locationManager?.stopUpdatingLocation()
            Self.isRunning = false
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.stop.value
            )
            result(true)
        } else if (call.method == "is_running_background_task") {
            result(Self.isRunning)
        } else if (call.method == "set_background_handler") {
            let args = call.arguments as? Dictionary<String, Any>
            Self.dispatcherRawHandle = args?["callbackDispatcherRawHandle"] as? Int
            Self.handlerRawHandle = args?["callbackHandlerRawHandle"] as? Int
            debugPrint("registered \(String(describing: args))")
            result(true)
        }
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        if (launchOptions[UIApplication.LaunchOptionsKey.location] != nil) {
            registerDispatchEngine()
            let locationManager = CLLocationManager()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.pausesLocationUpdatesAutomatically = false
            let (distanceFilter, desiredAccuracy) = UserDefaultsRepository.instance.fetch()
            locationManager.distanceFilter = distanceFilter
            locationManager.desiredAccuracy = desiredAccuracy.kCLLocation
            locationManager.delegate = self
            Self.locationManager = locationManager
            Self.locationManager?.startMonitoringSignificantLocationChanges()
            Self.locationManager?.startUpdatingLocation()
            Self.isRunning = true
        }
        return true
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        if (isEnabledEvenIfKilled) {
            Self.locationManager?.startMonitoringSignificantLocationChanges()
        }
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        if (isEnabledEvenIfKilled) {
            Self.locationManager?.startMonitoringSignificantLocationChanges()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let isEnabled = status == .authorizedAlways || status == .authorizedWhenInUse
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.permission(message: "\(isEnabled ? "enabled" : "disabled")").value
        )
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lat = locations.last?.coordinate.latitude
        let lng = locations.last?.coordinate.longitude
        let location = ["lat": lat, "lng": lng] as [String : Double?]
        
        BgEventStreamHandler.eventSink?(location)
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.updated(message: "lat:\(lat ?? 0) lng:\(lng ?? 0)").value
        )
        
        let callbackHandlerRawHandle = UserDefaultsRepository.instance.fetchCallbackHandlerRawHandle()
        let data = [
            "callbackHandlerRawHandle": callbackHandlerRawHandle,
            "lat": lat,
            "lng": lng
        ] as [String : Any?]
        Self.dispatchChannel?.invokeMethod("background_handler", arguments: data)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("didFailWithError: \(error)")
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.error(message: error.localizedDescription).value
        )
    }
    
    private func registerDispatchEngine() {
        if (Self.isRegisteredDispatchEngine) {
            return
        }
        let handle = UserDefaultsRepository.instance.fetchCallbackDispatcherRawHandle()
        if let info = FlutterCallbackCache.lookupCallbackInformation(Int64(handle)) {
            Self.dispatchEngine.run(withEntrypoint: info.callbackName, libraryURI: info.callbackLibraryPath)
            Self.onRegisterDispatchEngine?()
            let dispatchChannel = FlutterMethodChannel(
                name: "com.neverjp.background_task/methods",
                binaryMessenger: Self.dispatchEngine.binaryMessenger
            )
            dispatchChannel.setMethodCallHandler { call, result in
                if (call.method == "callback_channel_initialized") {
                    dispatchChannel.invokeMethod("notify_callback_dispatcher", arguments: nil)
                    result(true)
                }
            }
            Self.dispatchChannel = dispatchChannel
            Self.isRegisteredDispatchEngine = true
        }
    }
}
