package com.neverjp.background_task.lib

enum class ChannelName(
    val value: String
) {
    METHODS("com.neverjp.background_task/methods"),
    BG_EVENT("com.neverjp.background_task/bgEvent"),
    STATUS_EVENT("com.neverjp.background_task/statusEvent"),
}