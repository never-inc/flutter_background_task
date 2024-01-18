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

    static var locationManager: CLLocationManager?
    static var channel: FlutterMethodChannel?
    static var isUpdatingLocation = false
    
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
            let distanceFilter = args?["distanceFilter"] as? Double
            let desiredAccuracy: DesiredAccuracy
            if let value = args?["iOSDesiredAccuracy"] as? String, let type = DesiredAccuracy(rawValue: value) {
                desiredAccuracy = type
            } else {
                desiredAccuracy = .reduced
            }
            let locationManager = CLLocationManager()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.desiredAccuracy = desiredAccuracy.kCLLocation
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.distanceFilter = distanceFilter ?? kCLDistanceFilterNone
            locationManager.requestAlwaysAuthorization()
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
            
            Self.locationManager = locationManager
            Self.isUpdatingLocation = true
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.start(message: "\(desiredAccuracy)").value
            )
            result(true)
        } else if (call.method == "stop_background_task") {
            Self.locationManager?.stopUpdatingLocation()
            Self.isUpdatingLocation = false
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.stop.value
            )
            result(true)
        } else if (call.method == "is_running_background_task") {
            result(Self.isUpdatingLocation)
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
        Self.channel?.invokeMethod("backgroundHandler", arguments: location)
        BgEventStreamHandler.eventSink?(location)
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.updated(message: "lat:\(lat ?? 0) lng:\(lng ?? 0)").value
        )
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("didFailWithError: \(error)")
        StatusEventStreamHandler.eventSink?(
            StatusEventStreamHandler.StatusType.error(message: error.localizedDescription).value
        )
    }
}

final class BgEventStreamHandler: NSObject, FlutterStreamHandler {
    
    static var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        Self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Self.eventSink = nil
        return nil
    }
}

final class StatusEventStreamHandler: NSObject, FlutterStreamHandler {
    
    static var eventSink: FlutterEventSink?
    
    enum StatusType {
        case start(message: String)
        case stop
        case updated(message: String)
        case error(message: String)
        case permission(message: String)
        var value: String {
            switch (self) {
            case .start(message: let message):
                return "start,\(message)"
            case .stop:
                return "stop"
            case .updated(message: let message):
                return "updated,\(message)"
            case .error(message: let message):
                return "error,\(message)"
            case .permission(message: let message):
                return "permission,\(message)"
            }
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        Self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Self.eventSink = nil
        return nil
    }
}
