package com.neverjp.background_task.lib

import io.flutter.plugin.common.EventChannel

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