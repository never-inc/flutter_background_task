package com.example.background_task

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
class BackgroundTaskPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener, EventChannel.StreamHandler {

  private var context: Context? = null
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var bound: Boolean = false
  private var service: LocationUpdatesService? = null
  private var eventSink: EventChannel.EventSink? = null
  private var eventChannel: EventChannel? = null
  companion object {
    private val TAG = BackgroundTaskPlugin::class.java.simpleName
    private const val REQUEST_PERMISSIONS_REQUEST_CODE = 34
  }

  private val serviceConnection = object : ServiceConnection {
    override fun onServiceConnected(name: ComponentName, service: IBinder) {
      bound = true
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

    eventChannel = EventChannel(messenger, "com.neverjp.background_task/events")
    eventChannel?.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "start_background_task") {
      val distanceFilter = call.argument<Double>("distanceFilter")
      startLocationService(distanceFilter)
    } else if (call.method == "stop_background_task") {
      stopLocationService()
    }
    result.success(false)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    setActivity(binding)
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    this.onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    setActivity(null)
  }


  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    Log.i(TAG, "onRequestPermissionResult")
    if (requestCode == REQUEST_PERMISSIONS_REQUEST_CODE) {
      when {
        grantResults.isEmpty() -> Log.i(TAG, "User interaction was cancelled.")
        grantResults[0] == PackageManager.PERMISSION_GRANTED -> service?.requestLocationUpdates()
        else -> Log.d(TAG, "permission_denied_explanation")
      }
    }
    return true
  }

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    eventSink = sink
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
    eventChannel = null
  }

  private fun setActivity(binding: ActivityPluginBinding?) {
    this.activity = binding?.activity
    if(this.activity != null){
      if (!checkPermissions()) {
        requestPermissions()
      }
    } else {
      stopLocationService()
    }
  }

  private fun startLocationService(distanceFilter: Double?) {
    if (!bound) {
      val intent = Intent(context, LocationUpdatesService::class.java)
      intent.putExtra("distance_filter", distanceFilter)
      context!!.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
      LocationUpdatesService.locationStatusLiveData.observeForever {
        Log.i(TAG, "locationStatusLiveData: $it")
        eventSink?.success("updated")
      }
    }
  }

  private fun stopLocationService() {
    service?.removeLocationUpdates()
    if (bound) {
      context!!.unbindService(serviceConnection)
      bound = false
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
    if(activity == null) {
      return
    }
    val shouldProvideRationale = ActivityCompat.shouldShowRequestPermissionRationale(activity!!, Manifest.permission.ACCESS_FINE_LOCATION)
    if (shouldProvideRationale) {
      Log.i(TAG, "Displaying permission rationale to provide additional context.")
    } else {
      Log.i(TAG, "Requesting permission")
      ActivityCompat.requestPermissions(activity!!,
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
        REQUEST_PERMISSIONS_REQUEST_CODE)
    }
  }
}
