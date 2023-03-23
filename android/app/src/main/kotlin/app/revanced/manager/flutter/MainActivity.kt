package app.revanced.manager.flutter

import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import app.revanced.manager.flutter.utils.apk.ApkSigner
import app.revanced.manager.flutter.utils.logging.DefaultManagerLogger
import app.revanced.manager.flutter.utils.logging.ManagerLogger
import app.revanced.manager.flutter.utils.signing.SigningOptions
import app.revanced.patcher.Patcher
import app.revanced.patcher.PatcherOptions
import app.revanced.patcher.extensions.PatchExtensions.compatiblePackages
import app.revanced.patcher.extensions.PatchExtensions.patchName
import app.revanced.patcher.logging.Logger
import app.revanced.patcher.util.patch.PatchBundle
import dalvik.system.DexClassLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import app.revanced.patcher.apk.Apk
import app.revanced.patcher.apk.ApkBundle
import app.revanced.patcher.patch.PatchResult

private const val PATCHER_CHANNEL = "app.revanced.manager.flutter/patcher"
private const val INSTALLER_CHANNEL = "app.revanced.manager.flutter/installer"

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var installerChannel: MethodChannel
    val logger = DefaultManagerLogger()



    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {

        super.configureFlutterEngine(flutterEngine)
        val mainChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PATCHER_CHANNEL)
        installerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
        mainChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "runPatcher" -> {
                    val patchBundleFilePath = call.argument<String>("patchBundleFilePath")
                    val originalFilePath = call.argument<String>("originalFilePath")
                    val inputFilePath = call.argument<String>("inputFilePath")
                    val patchedFilePath = call.argument<String>("patchedFilePath")
                    val outFilePath = call.argument<String>("outFilePath")
                    val integrationsPath = call.argument<String>("integrationsPath")
                    val selectedPatches = call.argument<List<String>>("selectedPatches")
                    val cacheDirPath = call.argument<String>("cacheDirPath")
                    val keyStoreFilePath = call.argument<String>("keyStoreFilePath")
                    if (patchBundleFilePath != null &&
                        originalFilePath != null &&
                        inputFilePath != null &&
                        patchedFilePath != null &&
                        outFilePath != null &&
                        integrationsPath != null &&
                        selectedPatches != null &&
                        cacheDirPath != null &&
                        keyStoreFilePath != null
                    ) {
                        runPatcher(
                            result,
                            patchBundleFilePath,
                            originalFilePath,
                            inputFilePath,
                            patchedFilePath,
                            outFilePath,
                            integrationsPath,
                            selectedPatches,
                            cacheDirPath,
                            keyStoreFilePath
                        )
                    } else {
                        result.notImplemented()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }


    private fun runPatcher(
        result: MethodChannel.Result,
        patchBundleFilePath: String,
        originalFilePath: String,
        inputFilePath: String,
        patchedFilePath: String,
        outFilePath: String,
        integrationsPath: String,
        selectedPatches: List<String>,
        cacheDirPath: String,
        keyStoreFilePath: String
    ) {
        val originalFile = File(originalFilePath)
        val inputFile = File(inputFilePath)
        val patchedFile = File(patchedFilePath)
        val outFile = File(outFilePath)
        val integrations = File(integrationsPath)
        val keyStoreFile = File(keyStoreFilePath)

        Thread {
            try {
                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.1,
                            "header" to "",
                            "log" to "Copying original apk"
                        )
                    )
                }
                originalFile.copyTo(inputFile, true)

                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.2,
                            "header" to "Unpacking apk...",
                            "log" to "Unpacking input apk"
                        )
                    )
                }

                class ApkArgs {
                    lateinit var baseApk: String
                    var splitsArgs: SplitsArgs? = null

                    inner class SplitsArgs {
                        lateinit var libraryApk: String
                        lateinit var assetApk: String
                        lateinit var languageApk: String
                    }
                }

                // prepare apks
                val apkArgs = ApkArgs()
                apkArgs.baseApk = inputFilePath

                val baseApk = Apk.Base(apkArgs.baseApk, DefaultManagerLogger)
                /*
                val splitApk = apkArgs.splitsArgs?.let { args ->
                    with(args) {
                        ApkBundle.Split(
                            Apk.Split.Library(libraryApk, DefaultManagerLogger),
                            Apk.Split.Asset(assetApk, DefaultManagerLogger),
                            Apk.Split.Language(languageApk, DefaultManagerLogger)
                        )
                    }
                }*/

                    val patcher =
                    Patcher(
                        PatcherOptions(
                            ApkBundle(baseApk, null, DefaultManagerLogger),
                            cacheDirPath,
                            "/this/will/explode/later/and/is/unused/i/just/havent/removed/it/yet",
                            cacheDirPath,
                        )
                    )

                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf("progress" to 0.3, "header" to "", "log" to "")
                    )
                }
                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.4,
                            "header" to "Merging integrations...",
                            "log" to "Merging integrations"
                        )
                    )
                }
                patcher.addIntegrations(listOf(integrations))

                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.5,
                            "header" to "Applying patches...",
                            "log" to ""
                        )
                    )
                }

                val patches = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.CUPCAKE) {
                    PatchBundle.Dex(
                        patchBundleFilePath,
                    ).loadPatches(
                        cacheDirPath,
                        javaClass.classLoader,
                    ).filter { patch ->
                        (patch.compatiblePackages?.any { it.name == baseApk.packageMetadata.packageName } == true || patch.compatiblePackages.isNullOrEmpty()) &&
                                selectedPatches.any { it == patch.patchName }
                    }
                } else {
                    TODO("VERSION.SDK_INT < CUPCAKE")
                }
                patcher.addPatches(patches)
                patcher.execute(false).forEach { (patch, res) ->
                    if (res is PatchResult.Success) {
                        val msg = "Applied $patch"
                        handler.post {
                            installerChannel.invokeMethod(
                                "update",
                                mapOf(
                                    "progress" to 0.5,
                                    "header" to "",
                                    "log" to msg
                                )
                            )
                        }
                        return@forEach
                    }
                    val e = res as PatchResult.Error
                    val msg = "Failed to apply $patch: " + "${e.cause!!.message ?: e.cause!!::class.simpleName}"
                    handler.post {
                        installerChannel.invokeMethod(
                            "update",
                            mapOf("progress" to 0.5, "header" to "", "log" to msg)
                        )
                    }
                }

                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.7,
                            "header" to "Repacking apk...",
                            "log" to "Repacking patched apk"
                        )
                    )
                }
                val res = patcher.save()
                // TODO: loop over the apks in res instead.
                baseApk.save(patchedFile)
                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 0.9,
                            "header" to "Signing apk...",
                            "log" to ""
                        )
                    )
                }

                // Signer("ReVanced", "s3cur3p@ssw0rd").signApk(patchedFile, outFile, keyStoreFile)

                try {
                    ApkSigner(SigningOptions("ReVanced", "s3cur3p@ssw0rd", keyStoreFilePath)).signApk(patchedFile, outFile)
                } catch (e: Exception) {
                    //log to console
                    print("Error signing apk: ${e.message}")
                    e.printStackTrace()
                }

                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to 1.0,
                            "header" to "Finished!",
                            "log" to "Finished!"
                        )
                    )
                }
            } catch (ex: Throwable) {
                val stack = ex.stackTraceToString()
                handler.post {
                    installerChannel.invokeMethod(
                        "update",
                        mapOf(
                            "progress" to -100.0,
                            "header" to "Aborting...",
                            "log" to "An error occurred! Aborting\nError:\n$stack"
                        )
                    )
                }
            }
            handler.post { result.success(null) }
        }.start()
    }

    inner class ManagerLogger : Logger {
        override fun error(msg: String) {
            handler.post {
                installerChannel
                    .invokeMethod(
                        "update",
                        mapOf("progress" to -1.0, "header" to "", "log" to msg)
                    )
            }
        }

        override fun warn(msg: String) {
            handler.post {
                installerChannel.invokeMethod(
                    "update",
                    mapOf("progress" to -1.0, "header" to "", "log" to msg)
                )
            }
        }

        override fun info(msg: String) {
            handler.post {
                installerChannel.invokeMethod(
                    "update",
                    mapOf("progress" to -1.0, "header" to "", "log" to msg)
                )
            }
        }

        override fun trace(_msg: String) { /* unused */
        }
    }
}
