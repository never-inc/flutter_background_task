//
//  StatusEventStreamHandler.swift
//  background_task
//
//  Created by 中川祥平 on 2024/01/19.
//

import Flutter

final class StatusEventStreamHandler: NSObject, FlutterStreamHandler {
    
    static var eventSink: FlutterEventSink?
    
    enum StatusType {
        case start(message: String)
        case stop
        case updated(message: String)
        case error(message: String)
        case permission(message: String)
        var value: String {
            switch (self) {
            case .start(message: let message):
                return "start,\(message)"
            case .stop:
                return "stop"
            case .updated(message: let message):
                return "updated,\(message)"
            case .error(message: let message):
                return "error,\(message)"
            case .permission(message: let message):
                return "permission,\(message)"
            }
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        Self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Self.eventSink = nil
        return nil
    }
}
