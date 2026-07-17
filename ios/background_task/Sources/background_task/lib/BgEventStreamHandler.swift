//
//  BgEventStreamHandler.swift
//  background_task
//
//  Created by 中川祥平 on 2024/01/19.
//

import Flutter

final class BgEventStreamHandler: NSObject, FlutterStreamHandler {
    
    static var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        Self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Self.eventSink = nil
        return nil
    }
}
