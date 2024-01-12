package com.neverjp.background_task

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.lifecycle.Observer
import io.flutter.plugin.common.PluginRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** BackgroundTaskPlugin */
class BackgroundTaskPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

  private var context: Context? = null
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var isStarted: Boolean = false
  private var service: LocationUpdatesService? = null
  private var bgEventChannel: EventChannel? = null
  private var statusEventChannel: EventChannel? = null

  companion object {
    private val TAG = BackgroundTaskPlugin::class.java.simpleName
    private const val REQUEST_PERMISSIONS_REQUEST_CODE = 34
  }

  private val serviceConnection = object : ServiceConnection {
    override fun onServiceConnected(name: ComponentName, service: IBinder) {
      isStarted = true
      val binder = service as LocationUpdatesService.LocalBinder
      this@BackgroundTaskPlugin.service = binder.service
      requestLocation()
    }

    override fun onServiceDisconnected(name: ComponentName) {
      service = null
    }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val messenger = flutterPluginBinding.binaryMessenger
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(messenger, "com.neverjp.background_task/methods")
    channel.setMethodCallHandler(this)

    bgEventChannel = EventChannel(messenger, "com.neverjp.background_task/bgEvent")
    bgEventChannel?.setStreamHandler(BgEventStreamHandler())

    statusEventChannel = EventChannel(messenger, "com.neverjp.background_task/statusEvent")
    statusEventChannel?.setStreamHandler(StatusEventStreamHandler())
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "start_background_task" -> {
          val distanceFilter = call.argument<Double>("distanceFilter")
          startLocationService(distanceFilter)
          result.success(true)
        }
        "stop_background_task" -> {
          stopLocationService()
          result.success(true)
        }
        "set_android_notification" -> {
          setAndroidNotification(call.argument("title"),call.argument("message"),call.argument("icon"))
          result.success(true)
        }
        "is_running_background_task" -> {
          result.success(LocationUpdatesService.isStarted)
        }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    this.onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    stopLocationService()
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == REQUEST_PERMISSIONS_REQUEST_CODE) {
      when (PackageManager.PERMISSION_GRANTED) {
          grantResults[0] -> {
            service?.requestLocationUpdates()
            StatusEventStreamHandler.eventSink?.success(
              StatusEventStreamHandler.StatusType.Permission("enabled").value
            )
          }
          else ->  {
            StatusEventStreamHandler.eventSink?.success(
              StatusEventStreamHandler.StatusType.Permission("disabled").value
            )
            Log.d(TAG, "permission is denied")
          }
      }
    }
    return true
  }

  private val observer = Observer<Pair<Double?, Double?>> {
    val location = HashMap<String, Double?>()
    location["lat"] = it.first
    location["lng"] = it.second
    BgEventStreamHandler.eventSink?.success(location)
  }

  private fun startLocationService(distanceFilter: Double?) {
    if (!isStarted) {
      if (!checkPermissions()) {
        requestPermissions()
      }
      val intent = Intent(context, LocationUpdatesService::class.java)
      intent.putExtra("distanceFilter", distanceFilter)
      context!!.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
      LocationUpdatesService.locationStatusLiveData.observeForever(observer)
    }
  }

  private fun stopLocationService() {
    service?.removeLocationUpdates()
    LocationUpdatesService.locationStatusLiveData.removeObserver(observer)
    if (isStarted) {
      context!!.unbindService(serviceConnection)
      isStarted = false
    }
  }

  private fun requestLocation() {
    if (checkPermissions()) {
      service?.requestLocationUpdates()
    }
  }

  private fun checkPermissions(): Boolean {
    return PackageManager.PERMISSION_GRANTED == ActivityCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_FINE_LOCATION)
  }

  private fun requestPermissions() {
    activity?.also {
      val shouldProvideRationale = ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.ACCESS_FINE_LOCATION)
      if (!shouldProvideRationale) {
        ActivityCompat.requestPermissions(it,
          arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
          REQUEST_PERMISSIONS_REQUEST_CODE)
      }
    }
  }
  private fun setAndroidNotification(title: String?, message: String?, icon: String?) {
    if (title != null) LocationUpdatesService.NOTIFICATION_TITLE = title
    if (message != null) LocationUpdatesService.NOTIFICATION_MESSAGE = message
    if (icon != null) LocationUpdatesService.NOTIFICATION_ICON = icon
    service?.updateNotification()
  }
}

class BgEventStreamHandler:  EventChannel.StreamHandler  {
  companion object {
    var eventSink: EventChannel.EventSink? = null
  }

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    eventSink = sink
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class StatusEventStreamHandler:  EventChannel.StreamHandler  {

  sealed class StatusType {
    object Start : StatusType()
    object Stop : StatusType()
    class Updated(val message: String) : StatusType()
    class Error(val message: String) : StatusType()
    class Permission(val message: String) : StatusType()

    val value: String
      get() = when (this) {
        is Start -> "start"
        is Stop -> "stop"
        is Updated -> "updated,$message"
        is Error -> "error,$message"
        is Permission -> "permission,$message"
      }
  }

  companion object {
    var eventSink: EventChannel.EventSink? = null
  }

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    eventSink = sink
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}