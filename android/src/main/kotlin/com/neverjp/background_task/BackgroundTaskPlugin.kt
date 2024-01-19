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

package com.neverjp.background_task

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.lifecycle.Observer
import com.neverjp.background_task.lib.BgEventStreamHandler
import com.neverjp.background_task.lib.ChannelName
import com.neverjp.background_task.lib.StatusEventStreamHandler
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
  private var bgEventChannel: EventChannel? = null
  private var statusEventChannel: EventChannel? = null
  private var dispatcherRawHandle: Long? = null
  private var handlerRawHandle: Long? = null
  private val isEnabledEvenIfKilled: Boolean
    get() = pref.getBoolean(LocationUpdatesService.isEnabledEvenIfKilledKey, false)
  private val pref: SharedPreferences
    get() =  context!!.getSharedPreferences(LocationUpdatesService.PREF_FILE_NAME, Context.MODE_PRIVATE)

  companion object {
    private val TAG = BackgroundTaskPlugin::class.java.simpleName
    private const val REQUEST_PERMISSIONS_REQUEST_CODE = 34
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val messenger = flutterPluginBinding.binaryMessenger
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(messenger, ChannelName.METHODS.value)
    channel.setMethodCallHandler(this)

    bgEventChannel = EventChannel(messenger, ChannelName.BG_EVENT.value)
    bgEventChannel?.setStreamHandler(BgEventStreamHandler())

    statusEventChannel = EventChannel(messenger, ChannelName.STATUS_EVENT.value)
    statusEventChannel?.setStreamHandler(StatusEventStreamHandler())
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "start_background_task" -> {
          val distanceFilter = call.argument<Double>(LocationUpdatesService.distanceFilterKey)
          val isEnabledEvenIfKilled = call.argument<Boolean>("isEnabledEvenIfKilled") ?: false

          pref.edit().apply {
            remove(LocationUpdatesService.callbackDispatcherRawHandleKey)
            remove(LocationUpdatesService.callbackHandlerRawHandleKey)
            if (dispatcherRawHandle != null && handlerRawHandle != null) {
              putLong(LocationUpdatesService.callbackDispatcherRawHandleKey, dispatcherRawHandle ?: 0)
              putLong(LocationUpdatesService.callbackHandlerRawHandleKey, handlerRawHandle ?: 0)
            }
            putFloat(LocationUpdatesService.distanceFilterKey, distanceFilter?.toFloat() ?: 0.0.toFloat())
            putBoolean(LocationUpdatesService.isEnabledEvenIfKilledKey, isEnabledEvenIfKilled)
          }.apply()

          startLocationService()
          result.success(true)
        }
        "stop_background_task" -> {
          stopLocationService()
          pref.edit().putBoolean(LocationUpdatesService.isEnabledEvenIfKilledKey, false).apply()
          result.success(true)
        }
        "set_android_notification" -> {
          setAndroidNotification(call.argument("title"),call.argument("message"),call.argument("icon"))
          result.success(true)
        }
        "is_running_background_task" -> {
          result.success(LocationUpdatesService.isRunning)
        }
        "callback_channel_initialized" -> {
          channel.invokeMethod("notify_callback_dispatcher", null)
        }
        "set_background_handler" -> {
          dispatcherRawHandle = call.argument<Long>(LocationUpdatesService.callbackDispatcherRawHandleKey)
          handlerRawHandle = call.argument<Long>(LocationUpdatesService.callbackHandlerRawHandleKey)
          Log.d(TAG, "registered ${call.arguments}")
          result.success(true)
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
    if (isEnabledEvenIfKilled) {
      LocationUpdatesService.locationLiveData.removeObserver(locationObserver)
      LocationUpdatesService.statusLiveData.removeObserver(statusObserver)
    } else {
      stopLocationService()
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == REQUEST_PERMISSIONS_REQUEST_CODE) {
      when (PackageManager.PERMISSION_GRANTED) {
          grantResults[0] -> {
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

  private val locationObserver = Observer<Pair<Double?, Double?>> {
    val data = HashMap<String, Any?>()
    data["lat"] = it.first
    data["lng"] = it.second
    BgEventStreamHandler.eventSink?.success(data)
  }

  private val statusObserver = Observer<String> {
    StatusEventStreamHandler.eventSink?.success(it)
  }

  private fun startLocationService() {
    if (!checkPermissions()) {
      requestPermissions()
    }

    val intent = Intent(context, LocationUpdatesService::class.java)
    context!!.stopService(intent)

    LocationUpdatesService.locationLiveData.observeForever(locationObserver)
    LocationUpdatesService.statusLiveData.observeForever(statusObserver)

    context!!.startService(intent)
  }

  private fun stopLocationService() {
    if (!LocationUpdatesService.isRunning) {
      return
    }
    val intent = Intent(context, LocationUpdatesService::class.java)
    context!!.stopService(intent)
    LocationUpdatesService.statusLiveData.value = StatusEventStreamHandler.StatusType.Stop.value
    LocationUpdatesService.locationLiveData.removeObserver(locationObserver)
    LocationUpdatesService.statusLiveData.removeObserver(statusObserver)
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
  }
}


