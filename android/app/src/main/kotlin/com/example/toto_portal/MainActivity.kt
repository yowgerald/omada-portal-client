package com.example.toto_portal

import android.content.Context
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.toto_portal/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMacAddress" -> {
                        val macAddress = getMacAddress()
                        if (macAddress != null) {
                            result.success(macAddress)
                        } else {
                            result.error("UNAVAILABLE", "MAC address not available.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getMacAddress(): String? {
        val manager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = manager.connectionInfo
        return info.macAddress.toUpperCase()
    }
}
