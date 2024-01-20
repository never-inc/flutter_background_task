package com.neverjp.background_task.lib

import io.flutter.plugin.common.EventChannel

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