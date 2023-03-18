package app.revanced.manager.flutter.utils.logging

internal interface ManagerLogger {
    fun error(msg: String)
    fun info(msg: String)
    fun trace(msg: String)
    fun warn(msg: String)
}