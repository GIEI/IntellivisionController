package com.intellivision.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "intellivision_controller/preferences")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("controller", Context.MODE_PRIVATE)
                when (call.method) {
                    "getAll" -> result.success(mapOf("host" to prefs.getString("host", ""), "code" to prefs.getString("code", "482731")))
                    "setAll" -> {
                        val values = call.arguments as? Map<*, *>
                        prefs.edit().putString("host", values?.get("host") as? String ?: "")
                            .putString("code", values?.get("code") as? String ?: "482731").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
