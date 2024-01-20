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
        case isEnabledEvenIfKilled = "com.neverjp.background_task.isEnabledEvenIfKilled"
        case desiredAccuracy = "com.neverjp.background_task.desiredAccuracy"
        case callbackDispatcherRawHandle = "com.neverjp.background_task.callbackDispatcherRawHandle"
        case callbackHandlerRawHandle = "com.neverjp.background_task.callbackHandlerRawHandle"
        var value: String {
            rawValue
        }
    }
    
    func save(
        distanceFilter: Double,
        desiredAccuracy: BackgroundTaskPlugin.DesiredAccuracy
    ) {
        UserDefaults.standard.setValue(distanceFilter, forKey: Self.Key.distanceFilter.value)
        UserDefaults.standard.setValue(desiredAccuracy.rawValue, forKey: Self.Key.desiredAccuracy.value)
    }
    
    func save(callbackDispatcherRawHandle: Int, callbackHandlerRawHandle: Int) {
        UserDefaults.standard.setValue(callbackDispatcherRawHandle, forKey: Self.Key.callbackDispatcherRawHandle.value)
        UserDefaults.standard.setValue(callbackHandlerRawHandle, forKey: Self.Key.callbackHandlerRawHandle.value)
    }
    
    func saveIsEnabledEvenIfKilled(_ isEnabledEvenIfKilled: Bool) {
        UserDefaults.standard.setValue(isEnabledEvenIfKilled, forKey: Self.Key.isEnabledEvenIfKilled.value)
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
    
    func fetchIsEnabledEvenIfKilled() -> Bool {
        return UserDefaults.standard.bool(forKey: Self.Key.isEnabledEvenIfKilled.value)
    }
    
    func fetchCallbackDispatcherRawHandle() -> Int {
        return UserDefaults.standard.integer(forKey: Self.Key.callbackDispatcherRawHandle.value)
    }
    
    func fetchCallbackHandlerRawHandle() -> Int {
        return UserDefaults.standard.integer(forKey: Self.Key.callbackHandlerRawHandle.value)
    }
    
    func removeRawHandle() {
        UserDefaults.standard.removeObject(forKey: Self.Key.callbackDispatcherRawHandle.value)
        UserDefaults.standard.removeObject(forKey: Self.Key.callbackHandlerRawHandle.value)
    }
}
