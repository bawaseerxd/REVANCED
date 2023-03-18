package app.revanced.manager.flutter.utils.logging

import app.revanced.manager.flutter.MainActivity
import app.revanced.manager.flutter.utils.apk.ApkSigner
import app.revanced.manager.flutter.utils.logging.ManagerLogger
import java.util.logging.Logger
import java.util.logging.SimpleFormatter

class DefaultManagerLogger(
    private val logger: Logger = Logger.getLogger(MainActivity::class.java.name),
    private val errorLogger: Logger = Logger.getLogger(logger.name?.plus("Err") ?: "Err"),
) : ManagerLogger {

    init {
        logger.useParentHandlers = false
        if (logger.handlers.isEmpty()) {
            logger.addHandler(FlushingStreamHandler(System.out, SimpleFormatter()))
        }
    }

    companion object : app.revanced.patcher.logging.Logger {
        init {
            System.setProperty("java.util.logging.SimpleFormatter.format", "%4\$s: %5\$s %n")
        }
    }


    override fun error(msg: String) = errorLogger.severe(msg)
    override fun info(msg: String) = logger.info(msg)
    override fun trace(msg: String) = logger.finest(msg)
    override fun warn(msg: String) = errorLogger.warning(msg)

}