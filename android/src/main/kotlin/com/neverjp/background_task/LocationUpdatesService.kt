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

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
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

class LocationUpdatesService: Service() {

    private val binder = LocalBinder()
    private var notificationManager: NotificationManager? = null
    private var locationRequest: LocationRequest? = null
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var fusedLocationCallback: LocationCallback? = null
    private var isGoogleApiAvailable: Boolean = false
    private var serviceHandler: Handler? = null

    companion object {
        private val TAG = LocationUpdatesService::class.java.simpleName
        var isStarted: Boolean = false
            private set

        private val _locationStatusLiveData = MutableLiveData<Pair<Double?, Double?>>()
        val locationStatusLiveData: LiveData<Pair<Double?, Double?>> = _locationStatusLiveData

        var NOTIFICATION_TITLE = "Background task is running"
        var NOTIFICATION_MESSAGE = "Background task is running"
        var NOTIFICATION_ICON = "@mipmap/ic_launcher"
        private const val PACKAGE_NAME =
            "com.google.android.gms.location.sample.locationupdatesforegroundservice"
        private const val CHANNEL_ID = "background_task_channel_01"
        private const val EXTRA_STARTED_FROM_NOTIFICATION = "$PACKAGE_NAME.started_from_notification"

        private const val NOTIFICATION_ID = 373737
        const val UPDATE_INTERVAL_IN_MILLISECONDS: Long = 1000

        private lateinit var broadcastReceiver: BroadcastReceiver
        private const val STOP_SERVICE = "stop_service"
    }

    private val notification: NotificationCompat.Builder
        get() {
            val intent = Intent(this, getMainActivityClass(this))
            intent.putExtra(EXTRA_STARTED_FROM_NOTIFICATION, true)
            intent.action = "Localisation"
            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.getActivity(this, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            } else {
                PendingIntent.getActivity(this, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            }
            val builder = NotificationCompat.Builder(this, "BackgroundTaskLocation")
                .setContentTitle(NOTIFICATION_TITLE)
                .setOngoing(true)
                .setSound(null)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setSmallIcon(resources.getIdentifier(NOTIFICATION_ICON, "mipmap", packageName))
                .setWhen(System.currentTimeMillis())
                .setStyle(NotificationCompat.BigTextStyle().bigText(NOTIFICATION_MESSAGE))
                .setContentIntent(pendingIntent)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setChannelId(CHANNEL_ID)
            }

            return builder
        }

    inner class LocalBinder : Binder() {
        internal val service: LocationUpdatesService
            get() = this@LocationUpdatesService
    }

    private fun createRequest(distanceFilter: Float): LocationRequest =
        LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            UPDATE_INTERVAL_IN_MILLISECONDS
        ).apply {
            setMinUpdateDistanceMeters(distanceFilter)
            setGranularity(Granularity.GRANULARITY_PERMISSION_LEVEL)
            setWaitForAccurateLocation(true)
        }.build()

    override fun onBind(intent: Intent?): IBinder {
        val distanceFilter = intent?.getDoubleExtra("distanceFilter", 0.0)
        locationRequest = if (distanceFilter != null) {
            createRequest(distanceFilter.toFloat())
        } else {
            createRequest(0.0.toFloat())
        }
        return binder
    }

    override fun onCreate() {
        val googleAPIAvailability = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(applicationContext)
        isGoogleApiAvailable = googleAPIAvailability == ConnectionResult.SUCCESS
        Log.d(TAG,"isGoogleApiAvailable $isGoogleApiAvailable")
        if (isGoogleApiAvailable) {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            fusedLocationCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    super.onLocationResult(locationResult)
                    val newLastLocation = locationResult.lastLocation
                    val lat = newLastLocation?.latitude
                    val lng = newLastLocation?.latitude
                    _locationStatusLiveData.value = Pair(lat, lng)
                    StatusEventStreamHandler.eventSink?.success(
                        StatusEventStreamHandler.StatusType.Updated("lat:${lat ?: 0} lng:${lng ?: 0}").value
                    )
                }
            }
        }

        val handlerThread = HandlerThread(TAG)
        handlerThread.start()
        serviceHandler = Handler(handlerThread.looper)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Application Name"
            val mChannel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT)
            mChannel.setSound(null, null)
            notificationManager!!.createNotificationChannel(mChannel)
        }

        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == STOP_SERVICE) {
                    removeLocationUpdates()
                }
            }
        }

        val filter = IntentFilter()
        filter.addAction(STOP_SERVICE)
        registerReceiver(broadcastReceiver, filter)

        updateNotification()
    }

    override fun onDestroy() {
        super.onDestroy()
        isStarted = false
        unregisterReceiver(broadcastReceiver)
        try {
            if (isGoogleApiAvailable) {
                fusedLocationClient!!.removeLocationUpdates(fusedLocationCallback!!)
            }
            notificationManager!!.cancel(NOTIFICATION_ID)
            StatusEventStreamHandler.eventSink?.success(
                StatusEventStreamHandler.StatusType.Stop.value
            )
        } catch (unlikely: SecurityException) {
            Log.e(TAG, "$unlikely")
        }
    }

    @SuppressLint("MissingPermission")
    fun requestLocationUpdates() {
        try {
            if (isGoogleApiAvailable && locationRequest != null) {
                fusedLocationClient!!.requestLocationUpdates(
                    locationRequest!!,
                    fusedLocationCallback!!,
                    Looper.myLooper()
                )
            }
        } catch (unlikely: SecurityException) {
            Log.e(TAG, "$unlikely")
        }
    }

    fun updateNotification() {
        if (!isStarted) {
            isStarted = true
            startForeground(NOTIFICATION_ID, notification.build())
        } else {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification.build())
            Log.d(TAG, NOTIFICATION_TITLE)
        }
        StatusEventStreamHandler.eventSink?.success(
            StatusEventStreamHandler.StatusType.Start.value
        )
    }

    fun removeLocationUpdates() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    private fun getMainActivityClass(context: Context): Class<*>? {
        val packageName = context.packageName
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
        val className = launchIntent?.component?.className ?: return null
        return try {
            Class.forName(className)
        } catch (e: ClassNotFoundException) {
            e.printStackTrace()
            null
        }
    }
}