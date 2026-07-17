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
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Granularity
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.neverjp.background_task.lib.ChannelName
import com.neverjp.background_task.lib.StatusEventStreamHandler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.lang.ref.WeakReference
import java.util.ArrayDeque

class LocationUpdatesService : Service() {

    private val binder = LocalBinder()
    private var notificationManager: NotificationManager? = null
    private var locationRequest: LocationRequest? = null
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var fusedLocationCallback: LocationCallback? = null
    private var isGoogleApiAvailable = false
    private var broadcastReceiver: BroadcastReceiver? = null
    private var receiverRegistered = false
    private var backgroundEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var callbackDispatcherReady = false
    private val pendingBackgroundUpdates = ArrayDeque<Map<String, Any?>>()

    private val pref: SharedPreferences
        get() = applicationContext.getSharedPreferences(
            PREF_FILE_NAME,
            Context.MODE_PRIVATE,
        )

    enum class DesiredAccuracy(val accuracy: String) {
        PRIORITY_HIGH_ACCURACY("priorityHighAccuracy"),
        PRIORITY_BALANCED_POWER_ACCURACY("priorityBalancedPowerAccuracy"),
        PRIORITY_LOW_POWER("priorityLowPower"),
        PRIORITY_NO_POWER("priorityNoPower");

        companion object {
            fun lookup(value: String): DesiredAccuracy {
                return values().find { it.accuracy == value }
                    ?: PRIORITY_BALANCED_POWER_ACCURACY
            }
        }

        fun getLocationPriority(): Int {
            return when (this) {
                PRIORITY_HIGH_ACCURACY -> Priority.PRIORITY_HIGH_ACCURACY
                PRIORITY_BALANCED_POWER_ACCURACY ->
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY
                PRIORITY_LOW_POWER -> Priority.PRIORITY_LOW_POWER
                PRIORITY_NO_POWER -> Priority.PRIORITY_PASSIVE
            }
        }
    }

    companion object {
        private val TAG = LocationUpdatesService::class.java.simpleName

        @Volatile
        var isRunning: Boolean = false
            private set

        private val _locationLiveData = MutableLiveData<Pair<Double?, Double?>>()
        val locationLiveData: LiveData<Pair<Double?, Double?>> = _locationLiveData

        val statusLiveData = MutableLiveData<String>()

        var NOTIFICATION_TITLE = "Background task is running"
        var NOTIFICATION_MESSAGE = "Background task is running"
        var NOTIFICATION_ICON = "@mipmap/ic_launcher"

        private const val CHANNEL_ID = "background_task_channel_01"
        private const val EXTRA_STARTED_FROM_NOTIFICATION =
            "com.neverjp.background_task.started_from_notification"
        private const val NOTIFICATION_ID = 373737
        private const val STOP_SERVICE =
            "com.neverjp.background_task.STOP_SERVICE"
        private const val MAX_PENDING_BACKGROUND_UPDATES = 100

        const val isEnabledEvenIfKilledKey = "isEnabledEvenIfKilled"
        const val distanceFilterKey = "distanceFilter"
        const val desiredAccuracyKey = "androidDesiredAccuracy"
        const val updateIntervalInMillisecondsKey = "updateIntervalInMilliseconds"
        const val callbackDispatcherRawHandleKey = "callbackDispatcherRawHandle"
        const val callbackHandlerRawHandleKey = "callbackHandlerRawHandle"

        const val PREF_FILE_NAME = "BACKGROUND_TASK"

        private var activeService: WeakReference<LocationUpdatesService>? = null

        fun onCallbackChannelInitialized(channel: MethodChannel) {
            activeService?.get()?.onCallbackDispatcherReady(channel)
        }
    }

    private val notification: NotificationCompat.Builder
        get() {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.putExtra(EXTRA_STARTED_FROM_NOTIFICATION, true)
            val pendingIntent =
                launchIntent?.let {
                    val flags =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_IMMUTABLE or
                                PendingIntent.FLAG_UPDATE_CURRENT
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                    PendingIntent.getActivity(this, 1, it, flags)
                }

            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(NOTIFICATION_TITLE)
                .setOngoing(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setSmallIcon(resolveNotificationIcon())
                .setWhen(System.currentTimeMillis())
                .setContentText(NOTIFICATION_MESSAGE)
                .apply {
                    if (pendingIntent != null) {
                        setContentIntent(pendingIntent)
                    }
                }
        }

    inner class LocalBinder : Binder() {
        internal val service: LocationUpdatesService
            get() = this@LocationUpdatesService
    }

    private fun createRequest(
        distanceFilter: Float,
        updateIntervalInMilliseconds: Long,
        desiredAccuracy: DesiredAccuracy,
    ): LocationRequest {
        return LocationRequest.Builder(
            desiredAccuracy.getLocationPriority(),
            updateIntervalInMilliseconds.coerceAtLeast(0L),
        ).apply {
            setMinUpdateDistanceMeters(distanceFilter.coerceAtLeast(0f))
            setGranularity(Granularity.GRANULARITY_PERMISSION_LEVEL)
            setWaitForAccurateLocation(
                desiredAccuracy == DesiredAccuracy.PRIORITY_HIGH_ACCURACY,
            )
        }.build()
    }

    override fun onCreate() {
        super.onCreate()
        activeService = WeakReference(this)

        val googleApiAvailability =
            GoogleApiAvailability.getInstance()
                .isGooglePlayServicesAvailable(applicationContext)
        isGoogleApiAvailable = googleApiAvailability == ConnectionResult.SUCCESS
        Log.d(TAG, "isGoogleApiAvailable $isGoogleApiAvailable")
        if (isGoogleApiAvailable) {
            fusedLocationClient =
                LocationServices.getFusedLocationProviderClient(this)
            fusedLocationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(locationResult: LocationResult) {
                        val newLastLocation = locationResult.lastLocation
                        val lat = newLastLocation?.latitude
                        val lng = newLastLocation?.longitude
                        val value = "lat:${lat ?: 0} lng:${lng ?: 0}"
                        _locationLiveData.value = Pair(lat, lng)
                        statusLiveData.value =
                            StatusEventStreamHandler.StatusType.Updated(value).value

                        val callbackHandlerRawHandle =
                            pref.getLong(callbackHandlerRawHandleKey, 0)
                        if (callbackHandlerRawHandle != 0L) {
                            dispatchBackgroundUpdate(
                                hashMapOf(
                                    "callbackHandlerRawHandle" to
                                        callbackHandlerRawHandle,
                                    "lat" to (lat ?: 0.0),
                                    "lng" to (lng ?: 0.0),
                                ),
                            )
                        }
                    }
                }
        }

        notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    NOTIFICATION_TITLE,
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    setSound(null, null)
                    enableVibration(false)
                }
            notificationManager?.createNotificationChannel(channel)
        }

        registerStopReceiver()

        val distanceFilter = pref.getFloat(distanceFilterKey, 0f)
        val updateIntervalInMilliseconds =
            pref.getLong(updateIntervalInMillisecondsKey, 1000L)
        val desiredAccuracy =
            DesiredAccuracy.lookup(
                pref.getString(
                    desiredAccuracyKey,
                    DesiredAccuracy.PRIORITY_BALANCED_POWER_ACCURACY.accuracy,
                ).orEmpty(),
            )
        locationRequest =
            createRequest(
                distanceFilter,
                updateIntervalInMilliseconds,
                desiredAccuracy,
            )
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!checkRequiredLocationPermissions()) {
            statusLiveData.value =
                StatusEventStreamHandler.StatusType.Permission("disabled").value
            stopSelf(startId)
            return START_NOT_STICKY
        }

        try {
            updateNotification()
        } catch (exception: SecurityException) {
            Log.e(TAG, "Unable to promote location service to foreground.", exception)
            statusLiveData.value =
                StatusEventStreamHandler.StatusType.Error(
                    exception.message ?: "Unable to start foreground service.",
                ).value
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (backgroundEngine == null) {
            try {
                startBackgroundEngine()
            } catch (exception: RuntimeException) {
                Log.e(TAG, "Unable to start background Flutter engine.", exception)
                statusLiveData.value =
                    StatusEventStreamHandler.StatusType.Error(
                        exception.message
                            ?: "Unable to start background Flutter engine.",
                    ).value
            }
        }

        requestLocationUpdates()
        isRunning = true
        statusLiveData.value = StatusEventStreamHandler.StatusType.Start.value
        return if (isEnabledEvenIfKilled()) START_STICKY else START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!isEnabledEvenIfKilled()) {
            stopSelf()
            return
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        removeLocationUpdates()
        unregisterStopReceiver()

        methodChannel = null
        callbackDispatcherReady = false
        pendingBackgroundUpdates.clear()
        backgroundEngine?.destroy()
        backgroundEngine = null

        activeService?.clear()
        activeService = null
        isRunning = false
        statusLiveData.value = StatusEventStreamHandler.StatusType.Stop.value
        super.onDestroy()
    }

    @SuppressLint("MissingPermission")
    private fun requestLocationUpdates() {
        val request = locationRequest ?: return
        val callback = fusedLocationCallback ?: return
        val client = fusedLocationClient ?: return
        if (!isGoogleApiAvailable) {
            statusLiveData.value =
                StatusEventStreamHandler.StatusType.Error(
                    "Google Play services location API is unavailable.",
                ).value
            return
        }

        try {
            client.requestLocationUpdates(
                request,
                callback,
                Looper.getMainLooper(),
            )
        } catch (exception: SecurityException) {
            Log.e(TAG, "Unable to request location updates.", exception)
            statusLiveData.value =
                StatusEventStreamHandler.StatusType.Error(
                    exception.message ?: "Unable to request location updates.",
                ).value
        }
    }

    private fun updateNotification() {
        val builtNotification = notification.build()
        if (!isRunning) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    builtNotification,
                    FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, builtNotification)
            }
        } else {
            notificationManager?.notify(NOTIFICATION_ID, builtNotification)
        }
    }

    private fun removeLocationUpdates() {
        val callback = fusedLocationCallback
        if (callback != null) {
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        notificationManager?.cancel(NOTIFICATION_ID)
        isRunning = false
    }

    private fun registerStopReceiver() {
        val receiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == STOP_SERVICE) {
                        stopSelf()
                    }
                }
            }
        broadcastReceiver = receiver
        ContextCompat.registerReceiver(
            this,
            receiver,
            IntentFilter(STOP_SERVICE),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
    }

    private fun unregisterStopReceiver() {
        val receiver = broadcastReceiver
        if (receiverRegistered && receiver != null) {
            unregisterReceiver(receiver)
        }
        receiverRegistered = false
        broadcastReceiver = null
    }

    private fun startBackgroundEngine() {
        val callbackHandle = pref.getLong(callbackDispatcherRawHandleKey, 0)
        Log.d(TAG, "callbackDispatcherRawHandle: $callbackHandle")
        if (callbackHandle == 0L) {
            return
        }

        val callbackInfo =
            FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
        if (callbackInfo == null) {
            statusLiveData.value =
                StatusEventStreamHandler.StatusType.Error(
                    "Background callback dispatcher could not be resolved.",
                ).value
            return
        }

        val flutterLoader =
            FlutterLoader().apply {
                startInitialization(applicationContext)
                ensureInitializationComplete(
                    applicationContext,
                    emptyArray<String>(),
                )
            }
        val dartCallback =
            DartExecutor.DartCallback(
                applicationContext.assets,
                flutterLoader.findAppBundlePath(),
                callbackInfo,
            )
        backgroundEngine =
            FlutterEngine(applicationContext).apply {
                dartExecutor.executeDartCallback(dartCallback)
            }
    }

    private fun onCallbackDispatcherReady(channel: MethodChannel) {
        methodChannel = channel
        callbackDispatcherReady = true
        while (pendingBackgroundUpdates.isNotEmpty()) {
            channel.invokeMethod(
                "background_handler",
                pendingBackgroundUpdates.removeFirst(),
            )
        }
    }

    private fun dispatchBackgroundUpdate(data: Map<String, Any?>) {
        val channel = methodChannel
        if (callbackDispatcherReady && channel != null) {
            channel.invokeMethod("background_handler", data)
            return
        }

        if (pendingBackgroundUpdates.size >= MAX_PENDING_BACKGROUND_UPDATES) {
            pendingBackgroundUpdates.removeFirst()
        }
        pendingBackgroundUpdates.addLast(data)
    }

    private fun resolveNotificationIcon(): Int {
        val resourceReference = NOTIFICATION_ICON.removePrefix("@")
        val parts = resourceReference.split("/", limit = 2)
        val resourceType = if (parts.size == 2) parts[0] else "mipmap"
        val resourceName = if (parts.size == 2) parts[1] else parts[0]
        val configuredResource =
            resources.getIdentifier(resourceName, resourceType, packageName)
        if (configuredResource != 0) {
            return configuredResource
        }
        if (applicationInfo.icon != 0) {
            return applicationInfo.icon
        }
        return android.R.drawable.ic_menu_mylocation
    }

    private fun checkRequiredLocationPermissions(): Boolean {
        val hasForegroundPermission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ) == PackageManager.PERMISSION_GRANTED
        if (!hasForegroundPermission) {
            return false
        }

        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            !isEnabledEvenIfKilled() ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isEnabledEvenIfKilled(): Boolean {
        return pref.getBoolean(isEnabledEvenIfKilledKey, false)
    }
}
