//
//  Logger.swift
//  background_task
//
//  Created by 中川祥平 on 2024/01/18.
//

import Foundation

final class Logger {
    
    static func add(_ data: String) {
        if UserDefaults.standard.object(forKey: "logs") == nil {
            UserDefaults.standard.set([], forKey: "logs")
        }
        var logs = UserDefaults.standard.object(forKey: "logs") as! [String]
        logs.append(data)
        UserDefaults.standard.set(logs, forKey: "logs")
    }
    
    static func print() {
        if UserDefaults.standard.object(forKey: "logs") != nil {
            let logs : [String] = UserDefaults.standard.object(forKey: "logs") as! [String]
            debugPrint("logs: \(logs)")
        }
    }
    
    static func clear() {
        UserDefaults.standard.set([], forKey: "logs")
    }
}
