package com.dev.koru

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dev.koru.channels.BlockingMethodChannel
import com.dev.koru.channels.ProfileMethodChannel
import com.dev.koru.channels.StrictModeMethodChannel
import com.dev.koru.channels.ServiceEventChannel
import com.dev.koru.channels.PermissionMethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockingMethodChannel.register(flutterEngine, this)
        ProfileMethodChannel.register(flutterEngine, this)
        StrictModeMethodChannel.register(flutterEngine, this)
        ServiceEventChannel.register(flutterEngine)
        PermissionMethodChannel.register(flutterEngine, this)
    }
}
