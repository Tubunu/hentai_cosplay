package com.hentaicosplay.hentai_cosplay_downloader

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.*
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hentaicosplay/libbox"
    private var commandServer: CommandServer? = null
    private var isCoreRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val configJson = call.argument<String>("config")
                    if (configJson.isNullOrBlank()) {
                        result.error("INVALID_CONFIG", "Config JSON is empty", null)
                        return@setMethodCallHandler
                    }
                    thread {
                        try {
                            startLibbox(configJson)
                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Failed to start Libbox", e)
                            runOnUiThread {
                                result.error("START_FAILED", e.message ?: e.toString(), null)
                            }
                        }
                    }
                }
                "stop" -> {
                    thread {
                        try {
                            stopLibbox()
                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Failed to stop Libbox", e)
                            runOnUiThread {
                                result.success(false)
                            }
                        }
                    }
                }
                "isRunning" -> {
                    result.success(isCoreRunning)
                }
                "version" -> {
                    try {
                        result.success(Libbox.version())
                    } catch (e: Throwable) {
                        result.success("unknown")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Synchronized
    private fun startLibbox(configJson: String) {
        stopLibbox()

        val filesDir = applicationContext.filesDir
        val cacheDir = applicationContext.cacheDir
        val workingDir = File(filesDir, "singbox").apply { mkdirs() }

        val setupOptions = SetupOptions().apply {
            basePath = filesDir.absolutePath
            workingPath = workingDir.absolutePath
            tempPath = cacheDir.absolutePath
            debug = false
        }
        try {
            Libbox.setup(setupOptions)
        } catch (e: Throwable) {
            Log.w("MainActivity", "Libbox.setup: ${e.message}")
        }

        val handler = object : CommandServerHandler {
            override fun serviceReload() {}
            override fun serviceStop() {
                isCoreRunning = false
            }
            override fun setSystemProxyEnabled(enabled: Boolean) {}
            override fun writeDebugMessage(message: String?) {
                if (!message.isNullOrBlank()) {
                    Log.d("Libbox", message)
                }
            }
            override fun getSystemProxyStatus(): SystemProxyStatus {
                return SystemProxyStatus().apply {
                    available = false
                    enabled = false
                }
            }
        }

        val platformInterface = object : PlatformInterface {
            override fun autoDetectInterfaceControl(fd: Int) {}
            override fun clearDNSCache() {}
            override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}
            override fun findConnectionOwner(ipProtocol: Int, sourceAddress: String?, sourcePort: Int, destinationAddress: String?, destinationPort: Int): ConnectionOwner? = null
            override fun getInterfaces(): NetworkInterfaceIterator = object : NetworkInterfaceIterator {
                override fun hasNext(): Boolean = false
                override fun next(): NetworkInterface? = null
            }
            override fun includeAllNetworks(): Boolean = false
            override fun localDNSTransport(): LocalDNSTransport? = null
            override fun openTun(options: TunOptions?): Int = -1
            override fun readWIFIState(): WIFIState? = null
            override fun sendNotification(notification: Notification?) {}
            override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}
            override fun systemCertificates(): StringIterator = object : StringIterator {
                override fun hasNext(): Boolean = false
                override fun len(): Int = 0
                override fun next(): String = ""
            }
            override fun underNetworkExtension(): Boolean = false
            override fun usePlatformAutoDetectInterfaceControl(): Boolean = false
            override fun useProcFS(): Boolean = false
        }

        val server = CommandServer(handler, platformInterface)
        server.start()
        val overrideOptions = OverrideOptions().apply {
            autoRedirect = false
        }
        server.startOrReloadService(configJson, overrideOptions)
        commandServer = server
        isCoreRunning = true
        Log.i("MainActivity", "Libbox in-process proxy started successfully")
    }

    @Synchronized
    private fun stopLibbox() {
        val server = commandServer
        if (server != null) {
            try {
                server.closeService()
            } catch (e: Throwable) {
                Log.w("MainActivity", "closeService error: ${e.message}")
            }
            try {
                server.close()
            } catch (e: Throwable) {
                Log.w("MainActivity", "server.close error: ${e.message}")
            }
            commandServer = null
        }
        isCoreRunning = false
        Log.i("MainActivity", "Libbox in-process proxy stopped")
    }

    override fun onDestroy() {
        stopLibbox()
        super.onDestroy()
    }
}
