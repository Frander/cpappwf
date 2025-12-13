package com.clickpalm.clickpalmapp

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.util.Log

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // La aplicación se inicializa aquí
        Log.i("MainApplication", "ClickPalm Application iniciada")
    }
}
