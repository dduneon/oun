package com.dduneon.oun

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val reader = HealthWorkoutsChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oun/health_workouts")
            .setMethodCallHandler(reader::handle)
    }
}
