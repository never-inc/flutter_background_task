import Flutter
import UIKit
import CoreLocation

public class BackgroundTaskPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    static var locationManager: CLLocationManager?
    static var channel: FlutterMethodChannel?
    static var isUpdatingLocation = false
    private var bgEventSink: FlutterEventSink?
    private var isRunningEventSink: FlutterEventSink?

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
            let locationManager = CLLocationManager()
            BackgroundTaskPlugin.locationManager = locationManager
            BackgroundTaskPlugin.locationManager?.delegate = self
            BackgroundTaskPlugin.locationManager?.allowsBackgroundLocationUpdates = true
            BackgroundTaskPlugin.locationManager?.showsBackgroundLocationIndicator = true
            if #available(iOS 14.0, *) {
               BackgroundTaskPlugin.locationManager?.desiredAccuracy = kCLLocationAccuracyReduced
            } else {
               BackgroundTaskPlugin.locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
            BackgroundTaskPlugin.locationManager?.pausesLocationUpdatesAutomatically = false
            BackgroundTaskPlugin.locationManager?.requestAlwaysAuthorization()
            let args = call.arguments as? Dictionary<String, Any>
            let distanceFilter = args?["distanceFilter"] as? Double
            BackgroundTaskPlugin.locationManager?.distanceFilter = distanceFilter ?? kCLDistanceFilterNone
            BackgroundTaskPlugin.locationManager?.startUpdatingLocation()
            BackgroundTaskPlugin.isUpdatingLocation = true
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.start.value
            )
            result(true)
        } else if (call.method == "stop_background_task") {
            BackgroundTaskPlugin.locationManager?.stopUpdatingLocation()
            BackgroundTaskPlugin.locationManager?.startMonitoringVisits()
            BackgroundTaskPlugin.isUpdatingLocation = false
            StatusEventStreamHandler.eventSink?(
                StatusEventStreamHandler.StatusType.stop.value
            )
            result(true)
        } else if (call.method == "is_running_background_task") {
            result(BackgroundTaskPlugin.isUpdatingLocation)
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
        case start
        case stop
        case updated(message: String)
        case error(message: String)
        case permission(message: String)
        var value: String {
            switch (self) {
            case .start:
                return "start"
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
