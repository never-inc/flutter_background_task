//
//  ChannelName.swift
//  background_task
//
//  Created by 中川祥平 on 2024/01/25.
//

import Foundation

enum ChannelName: String {
    case methods = "com.neverjp.background_task/methods"
    case bgEvent = "com.neverjp.background_task/bgEvent"
    case statusEvent = "com.neverjp.background_task/statusEvent"
    
    var value: String {
        rawValue
    }
}
