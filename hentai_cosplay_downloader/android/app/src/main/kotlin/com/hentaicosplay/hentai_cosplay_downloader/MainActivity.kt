package com.hentaicosplay.hentai_cosplay_downloader

import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.*
import java.io.File
import java.security.KeyStore
import java.security.cert.X509Certificate
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
            fixAndroidStack = true
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
            override fun findConnectionOwner(ipProtocol: Int, sourceAddress: String?, sourcePort: Int, destinationAddress: String?, destinationPort: Int): ConnectionOwner? = ConnectionOwner()
            override fun getInterfaces(): NetworkInterfaceIterator = object : NetworkInterfaceIterator {
                override fun hasNext(): Boolean = false
                override fun next(): NetworkInterface = NetworkInterface()
            }
            override fun includeAllNetworks(): Boolean = false
            override fun localDNSTransport(): LocalDNSTransport? = object : LocalDNSTransport {
                override fun exchange(ctx: ExchangeContext?, message: ByteArray?) {
                    ctx?.errorCode(1)
                }
                override fun lookup(ctx: ExchangeContext?, network: String?, domain: String?) {
                    ctx?.errorCode(1)
                }
                override fun raw(): Boolean = false
            }
            override fun openTun(options: TunOptions?): Int = -1
            override fun readWIFIState(): WIFIState? = WIFIState("", "")
            override fun sendNotification(notification: Notification?) {}
            override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}
            override fun systemCertificates(): StringIterator {
                val certList = mutableListOf<String>()
                try {
                    val keyStore = KeyStore.getInstance("AndroidCAStore")
                    keyStore.load(null, null)
                    val aliases = keyStore.aliases()
                    while (aliases.hasMoreElements()) {
                        val alias = aliases.nextElement()
                        val cert = keyStore.getCertificate(alias) as? X509Certificate ?: continue
                        val encoded = Base64.encodeToString(cert.encoded, Base64.NO_WRAP)
                        certList.add("-----BEGIN CERTIFICATE-----\n$encoded\n-----END CERTIFICATE-----")
                    }
                } catch (e: Throwable) {
                    Log.w("MainActivity", "Failed to load system certificates: ${e.message}")
                }
                var index = 0
                return object : StringIterator {
                    override fun hasNext(): Boolean = index < certList.size
                    override fun len(): Int = certList.size
                    override fun next(): String = if (index < certList.size) certList[index++] else ""
                }
            }
            override fun underNetworkExtension(): Boolean = false
            override fun usePlatformAutoDetectInterfaceControl(): Boolean = false
            override fun useProcFS(): Boolean = true
        }

        val server = CommandServer(handler, platformInterface)
        try {
            server.startWithTemporaryPort()
        } catch (e: Throwable) {
            Log.w("MainActivity", "startWithTemporaryPort error: ${e.message}")
            try {
                server.start()
            } catch (e2: Throwable) {
                Log.w("MainActivity", "server.start error: ${e2.message}")
            }
        }
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
