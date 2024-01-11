import Flutter
import UIKit
import CoreLocation

public class BackgroundTaskPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, FlutterStreamHandler {

   static var locationManager: CLLocationManager?
   static var channel: FlutterMethodChannel?
   private var eventSink: FlutterEventSink?

   public static func register(with registrar: FlutterPluginRegistrar) {
       let instance = BackgroundTaskPlugin()

       let channel = FlutterMethodChannel(name: "com.neverjp.background_task/methods", binaryMessenger: registrar.messenger())
       registrar.addMethodCallDelegate(instance, channel: channel)
       channel.setMethodCallHandler(instance.handle)
       BackgroundTaskPlugin.channel = channel

       let eventChannel = FlutterEventChannel(name: "com.neverjp.background_task/events", binaryMessenger: registrar.messenger())
       eventChannel.setStreamHandler(instance)
   }

   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       BackgroundTaskPlugin.locationManager = CLLocationManager()
       BackgroundTaskPlugin.locationManager?.delegate = self
       BackgroundTaskPlugin.locationManager?.allowsBackgroundLocationUpdates = true
       BackgroundTaskPlugin.locationManager?.showsBackgroundLocationIndicator = true
       if #available(iOS 14.0, *) {
           BackgroundTaskPlugin.locationManager?.desiredAccuracy = kCLLocationAccuracyReduced
       } else {
           BackgroundTaskPlugin.locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
       }
       BackgroundTaskPlugin.locationManager?.pausesLocationUpdatesAutomatically = false
       BackgroundTaskPlugin.locationManager?.activityType = .other

       if (call.method == "start_background_task") {
           BackgroundTaskPlugin.locationManager?.requestAlwaysAuthorization()
           let args = call.arguments as? Dictionary<String, Any>
           let distanceFilter = args?["distanceFilter"] as? Double
           BackgroundTaskPlugin.locationManager?.distanceFilter = distanceFilter ?? 0
           BackgroundTaskPlugin.locationManager?.startUpdatingLocation()
       } else if (call.method == "stop_background_task") {
           BackgroundTaskPlugin.locationManager?.stopUpdatingLocation()
       }
       result(true)
   }

   public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
       // ignore
   }

   public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
       eventSink?("updated")
   }

   public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
       self.eventSink = eventSink
       return nil
   }

   public func onCancel(withArguments arguments: Any?) -> FlutterError? {
       eventSink = nil
       return nil
   }
}
