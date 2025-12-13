package com.clickpalm.clickpalmapp

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.tech.IsoDep
import android.nfc.tech.MifareClassic
import android.nfc.tech.MifareUltralight
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.nfc.tech.NfcA
import android.nfc.tech.NfcB
import android.nfc.tech.NfcF
import android.nfc.tech.NfcV
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var nfcAdapter: NfcAdapter? = null
    private var pendingIntent: PendingIntent? = null
    private var intentFiltersArray: Array<IntentFilter>? = null
    private var techListsArray: Array<Array<String>>? = null
    private var nfcSupported: Boolean = false

    companion object {
        private const val NFC_CHANNEL = "com.clickpalm.clickpalmapp/nfc"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Inicializar NFC ANTES de llamar a super.onCreate()
        // para evitar conflictos con el plugin nfc_manager
        try {
            initializeNfc()
        } catch (e: Exception) {
            Log.w("MainActivity", "NFC initialization failed: ${e.message}")
            nfcSupported = false
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Configurar MethodChannel para NFC
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNfcSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NFC_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error abriendo ajustes NFC: ${e.message}")
                        // Fallback: abrir ajustes generales de conexiones inalámbricas
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", "No se pudo abrir ajustes: ${e2.message}", null)
                        }
                    }
                }
                "isNfcEnabled" -> {
                    val adapter = NfcAdapter.getDefaultAdapter(this)
                    result.success(adapter?.isEnabled ?: false)
                }
                "hasNfcHardware" -> {
                    val adapter = NfcAdapter.getDefaultAdapter(this)
                    result.success(adapter != null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeNfc() {
        // Inicializar NFC adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        if (nfcAdapter == null) {
            Log.i("MainActivity", "NFC no está disponible en este dispositivo")
            nfcSupported = false
            return
        }

        nfcSupported = true

        // Crear PendingIntent para foreground dispatch
        val intent = Intent(this, javaClass).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Configurar filtros de intent para todos los tipos de tags NFC
        try {
            val ndef = IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED).apply {
                addDataType("*/*")
            }
            val tech = IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)
            val tag = IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED)

            intentFiltersArray = arrayOf(ndef, tech, tag)

            // Configurar lista de tecnologías NFC soportadas
            techListsArray = arrayOf(
                arrayOf(Ndef::class.java.name),
                arrayOf(NdefFormatable::class.java.name),
                arrayOf(MifareClassic::class.java.name),
                arrayOf(MifareUltralight::class.java.name),
                arrayOf(NfcA::class.java.name),
                arrayOf(NfcB::class.java.name),
                arrayOf(NfcF::class.java.name),
                arrayOf(NfcV::class.java.name),
                arrayOf(IsoDep::class.java.name)
            )

            Log.i("MainActivity", "NFC inicializado correctamente")
        } catch (e: IntentFilter.MalformedMimeTypeException) {
            Log.e("MainActivity", "Error al configurar MIME type para NFC: ${e.message}")
            nfcSupported = false
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al configurar NFC: ${e.message}")
            nfcSupported = false
        }
    }

    override fun onResume() {
        super.onResume()
        // Habilitar foreground dispatch solo si NFC está soportado y configurado
        if (nfcSupported && nfcAdapter != null && intentFiltersArray != null) {
            try {
                nfcAdapter?.enableForegroundDispatch(this, pendingIntent, intentFiltersArray, techListsArray)
            } catch (e: Exception) {
                Log.w("MainActivity", "Error al habilitar NFC foreground dispatch: ${e.message}")
            }
        }
    }

    override fun onPause() {
        super.onPause()
        // Deshabilitar foreground dispatch solo si NFC está soportado
        if (nfcSupported && nfcAdapter != null) {
            try {
                nfcAdapter?.disableForegroundDispatch(this)
            } catch (e: Exception) {
                Log.w("MainActivity", "Error al deshabilitar NFC foreground dispatch: ${e.message}")
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Actualizar el intent para que Flutter pueda procesarlo
        setIntent(intent)
    }
}
