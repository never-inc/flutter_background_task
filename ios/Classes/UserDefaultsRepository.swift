//
//  UserDefaultsRepository.swift
//  background_task
//
//  Created by 中川祥平 on 2024/01/18.
//

import Foundation

struct UserDefaultsRepository {
    static let instance = UserDefaultsRepository()
    
    enum Key: String {
        case distanceFilter = "com.neverjp.background_task.distanceFilter"
        case desiredAccuracy = "com.neverjp.background_task.desiredAccuracy"
        var value: String {
            rawValue
        }
    }
    
    func save(distanceFilter: Double, desiredAccuracy: BackgroundTaskPlugin.DesiredAccuracy) {
        UserDefaults.standard.setValue(distanceFilter, forKey: Self.Key.distanceFilter.value)
        UserDefaults.standard.setValue(desiredAccuracy.rawValue, forKey: Self.Key.desiredAccuracy.value)
    }
    
    func fetch() -> (distanceFilter: Double, desiredAccuracy: BackgroundTaskPlugin.DesiredAccuracy) {
        let distanceFilter = UserDefaults.standard.double(forKey: Self.Key.distanceFilter.value)
        let desiredAccuracy: BackgroundTaskPlugin.DesiredAccuracy
        if let rawValue = UserDefaults.standard.string(forKey: Self.Key.desiredAccuracy.value),
            let data = BackgroundTaskPlugin.DesiredAccuracy(rawValue: rawValue)  {
            desiredAccuracy = data
        } else {
            desiredAccuracy = BackgroundTaskPlugin.DesiredAccuracy.reduced
        }
        return (distanceFilter: distanceFilter, desiredAccuracy: desiredAccuracy)
    }
    
    func remove() {
        UserDefaults.standard.removeObject(forKey: Self.Key.distanceFilter.value)
        UserDefaults.standard.removeObject(forKey: Self.Key.desiredAccuracy.value)
    }
}
