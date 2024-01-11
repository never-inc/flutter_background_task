package com.example.background_task

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
    private var isStarted: Boolean = false
    private var serviceHandler: Handler? = null

    companion object {
        private val TAG = LocationUpdatesService::class.java.simpleName

        private val _locationStatusLiveData = MutableLiveData<String>()
        val locationStatusLiveData: LiveData<String> = _locationStatusLiveData

        var NOTIFICATION_TITLE = "Background service is running"
        var NOTIFICATION_MESSAGE = "Background service is running"
        var NOTIFICATION_ICON = "@mipmap/ic_launcher"
        private const val PACKAGE_NAME =
            "com.google.android.gms.location.sample.locationupdatesforegroundservice"
        private const val CHANNEL_ID = "background_task_channel_01"
        private const val EXTRA_STARTED_FROM_NOTIFICATION = "$PACKAGE_NAME.started_from_notification"

        private const val NOTIFICATION_ID = 12345678
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
            val builder = NotificationCompat.Builder(this, "BackgroundLocation")
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

    // https://tomas-repcik.medium.com/locationrequest-create-got-deprecated-how-to-fix-it-e4f814138764
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
        val distanceFilter = intent?.getDoubleExtra("distance_filter", 0.0)
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
        println("isGoogleApiAvailable $isGoogleApiAvailable")
        if (isGoogleApiAvailable) {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            fusedLocationCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    super.onLocationResult(locationResult)
                    _locationStatusLiveData.value = "updated"
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
        }
    }

    fun removeLocationUpdates() {
        stopForeground(true)
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