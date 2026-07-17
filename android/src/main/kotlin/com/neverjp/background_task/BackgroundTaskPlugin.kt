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
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import com.neverjp.background_task.lib.BgEventStreamHandler
import com.neverjp.background_task.lib.ChannelName
import com.neverjp.background_task.lib.StatusEventStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** BackgroundTaskPlugin */
class BackgroundTaskPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private var context: Context? = null
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var bgEventChannel: EventChannel? = null
    private var statusEventChannel: EventChannel? = null
    private var dispatcherRawHandle: Long? = null
    private var handlerRawHandle: Long? = null
    private var observersAttached = false
    private var pendingStartResult: Result? = null
    private var pendingStartRequiresBackgroundPermission = false

    private val pref: SharedPreferences
        get() = requireNotNull(context).getSharedPreferences(
            LocationUpdatesService.PREF_FILE_NAME,
            Context.MODE_PRIVATE,
        )

    companion object {
        private val TAG = BackgroundTaskPlugin::class.java.simpleName
        private const val REQUEST_FOREGROUND_LOCATION_PERMISSION = 34
        private const val REQUEST_BACKGROUND_LOCATION_PERMISSION = 35
    }

    override fun onAttachedToEngine(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
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
                val distanceFilter =
                    call.argument<Double>(LocationUpdatesService.distanceFilterKey)
                val updateIntervalInMilliseconds =
                    call.argument<Double>(
                        LocationUpdatesService.updateIntervalInMillisecondsKey,
                    )
                val desiredAccuracy =
                    call.argument<String>(LocationUpdatesService.desiredAccuracyKey)
                        ?: "priorityBalancedPowerAccuracy"
                val isEnabledEvenIfKilled =
                    call.argument<Boolean>(LocationUpdatesService.isEnabledEvenIfKilledKey)
                        ?: false

                pref.edit().apply {
                    remove(LocationUpdatesService.callbackDispatcherRawHandleKey)
                    remove(LocationUpdatesService.callbackHandlerRawHandleKey)
                    val dispatcherHandle = dispatcherRawHandle
                    val handlerHandle = handlerRawHandle
                    if (dispatcherHandle != null && handlerHandle != null) {
                        putLong(
                            LocationUpdatesService.callbackDispatcherRawHandleKey,
                            dispatcherHandle,
                        )
                        putLong(
                            LocationUpdatesService.callbackHandlerRawHandleKey,
                            handlerHandle,
                        )
                    }
                    putFloat(
                        LocationUpdatesService.distanceFilterKey,
                        distanceFilter?.toFloat() ?: 0f,
                    )
                    putLong(
                        LocationUpdatesService.updateIntervalInMillisecondsKey,
                        updateIntervalInMilliseconds?.toLong() ?: 1000L,
                    )
                    putString(LocationUpdatesService.desiredAccuracyKey, desiredAccuracy)
                    putBoolean(
                        LocationUpdatesService.isEnabledEvenIfKilledKey,
                        isEnabledEvenIfKilled,
                    )
                }.apply()

                startLocationService(
                    result = result,
                    requiresBackgroundPermission = isEnabledEvenIfKilled,
                )
            }

            "stop_background_task" -> {
                pendingStartResult?.error(
                    "START_CANCELLED",
                    "The pending background task start was cancelled.",
                    null,
                )
                pendingStartResult = null
                pref.edit()
                    .putBoolean(LocationUpdatesService.isEnabledEvenIfKilledKey, false)
                    .apply()
                stopLocationService()
                result.success(true)
            }

            "set_android_notification" -> {
                setAndroidNotification(
                    call.argument("title"),
                    call.argument("message"),
                    call.argument("icon"),
                )
                result.success(true)
            }

            "is_running_background_task" -> {
                result.success(LocationUpdatesService.isRunning)
            }

            "callback_channel_initialized" -> {
                LocationUpdatesService.onCallbackChannelInitialized(channel)
                channel.invokeMethod("notify_callback_dispatcher", null)
                result.success(true)
            }

            "set_background_handler" -> {
                dispatcherRawHandle =
                    call.argument<Long>(
                        LocationUpdatesService.callbackDispatcherRawHandleKey,
                    )
                handlerRawHandle =
                    call.argument<Long>(
                        LocationUpdatesService.callbackHandlerRawHandleKey,
                    )
                Log.d(TAG, "registered ${call.arguments}")
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachObservers()
        channel.setMethodCallHandler(null)
        bgEventChannel?.setStreamHandler(null)
        statusEventChannel?.setStreamHandler(null)
        bgEventChannel = null
        statusEventChannel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity(cancelPendingStart = false)
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity(cancelPendingStart = true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (
            requestCode != REQUEST_FOREGROUND_LOCATION_PERMISSION &&
            requestCode != REQUEST_BACKGROUND_LOCATION_PERMISSION
        ) {
            return false
        }

        val permissionGranted =
            if (requestCode == REQUEST_FOREGROUND_LOCATION_PERMISSION) {
                hasForegroundLocationPermission()
            } else {
                hasBackgroundLocationPermission()
            }
        StatusEventStreamHandler.eventSink?.success(
            StatusEventStreamHandler.StatusType.Permission(
                if (permissionGranted) "enabled" else "disabled",
            ).value,
        )

        val pendingResult = pendingStartResult ?: return true
        if (!permissionGranted) {
            pendingStartResult = null
            pendingResult.error(
                "LOCATION_PERMISSION_DENIED",
                if (requestCode == REQUEST_BACKGROUND_LOCATION_PERMISSION) {
                    "Background location permission is required when " +
                        "isEnabledEvenIfKilled is true."
                } else {
                    "Location permission is required to start the background task."
                },
                null,
            )
            return true
        }

        if (
            pendingStartRequiresBackgroundPermission &&
            !hasBackgroundLocationPermission()
        ) {
            if (!requestBackgroundLocationPermission()) {
                pendingStartResult = null
                pendingResult.error(
                    "BACKGROUND_LOCATION_PERMISSION_UNAVAILABLE",
                    "Unable to request background location permission.",
                    null,
                )
            }
            return true
        }

        pendingStartResult = null
        launchLocationService(pendingResult)
        return true
    }

    private val locationObserver = Observer<Pair<Double?, Double?>> {
        val data = hashMapOf<String, Any?>(
            "lat" to it.first,
            "lng" to it.second,
        )
        BgEventStreamHandler.eventSink?.success(data)
    }

    private val statusObserver = Observer<String> {
        StatusEventStreamHandler.eventSink?.success(it)
    }

    private fun startLocationService(
        result: Result,
        requiresBackgroundPermission: Boolean,
    ) {
        if (pendingStartResult != null) {
            result.error(
                "START_ALREADY_PENDING",
                "A background task start is already waiting for permission.",
                null,
            )
            return
        }

        if (!hasForegroundLocationPermission()) {
            pendingStartResult = result
            pendingStartRequiresBackgroundPermission = requiresBackgroundPermission
            if (!requestForegroundLocationPermission()) {
                pendingStartResult = null
                result.error(
                    "LOCATION_PERMISSION_UNAVAILABLE",
                    "Unable to request location permission without an attached Activity.",
                    null,
                )
            }
            return
        }

        if (requiresBackgroundPermission && !hasBackgroundLocationPermission()) {
            pendingStartResult = result
            pendingStartRequiresBackgroundPermission = true
            if (!requestBackgroundLocationPermission()) {
                pendingStartResult = null
                result.error(
                    "BACKGROUND_LOCATION_PERMISSION_UNAVAILABLE",
                    "Unable to request background location permission.",
                    null,
                )
            }
            return
        }

        launchLocationService(result)
    }

    private fun launchLocationService(result: Result) {
        val appContext = context
        if (appContext == null) {
            result.error(
                "PLUGIN_DETACHED",
                "The plugin is not attached to an Android context.",
                null,
            )
            return
        }

        attachObservers()
        val intent = Intent(appContext, LocationUpdatesService::class.java)
        try {
            ContextCompat.startForegroundService(appContext, intent)
            result.success(true)
        } catch (exception: RuntimeException) {
            detachObservers()
            Log.e(TAG, "Unable to start location foreground service.", exception)
            result.error(
                "FOREGROUND_SERVICE_START_FAILED",
                exception.message,
                null,
            )
        }
    }

    private fun stopLocationService() {
        val appContext = context
        if (appContext != null) {
            appContext.stopService(
                Intent(appContext, LocationUpdatesService::class.java),
            )
        }
        LocationUpdatesService.statusLiveData.value =
            StatusEventStreamHandler.StatusType.Stop.value
        detachObservers()
    }

    private fun attachObservers() {
        if (observersAttached) {
            return
        }
        LocationUpdatesService.locationLiveData.observeForever(locationObserver)
        LocationUpdatesService.statusLiveData.observeForever(statusObserver)
        observersAttached = true
    }

    private fun detachObservers() {
        if (!observersAttached) {
            return
        }
        LocationUpdatesService.locationLiveData.removeObserver(locationObserver)
        LocationUpdatesService.statusLiveData.removeObserver(statusObserver)
        observersAttached = false
    }

    private fun hasForegroundLocationPermission(): Boolean {
        val appContext = context ?: return false
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasBackgroundLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }
        val appContext = context ?: return false
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestForegroundLocationPermission(): Boolean {
        val currentActivity = activity ?: return false
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
            REQUEST_FOREGROUND_LOCATION_PERMISSION,
        )
        return true
    }

    private fun requestBackgroundLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }
        val currentActivity = activity ?: return false
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQUEST_BACKGROUND_LOCATION_PERMISSION,
        )
        return true
    }

    private fun detachFromActivity(cancelPendingStart: Boolean) {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        if (cancelPendingStart) {
            pendingStartResult?.error(
                "ACTIVITY_DETACHED",
                "The Activity was detached while requesting location permission.",
                null,
            )
            pendingStartResult = null
        }
    }

    private fun setAndroidNotification(
        title: String?,
        message: String?,
        icon: String?,
    ) {
        if (title != null) {
            LocationUpdatesService.NOTIFICATION_TITLE = title
        }
        if (message != null) {
            LocationUpdatesService.NOTIFICATION_MESSAGE = message
        }
        if (icon != null) {
            LocationUpdatesService.NOTIFICATION_ICON = icon
        }
    }
}
