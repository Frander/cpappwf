// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '/components/nfc_disabled_alert_widget.dart';

/// Canal para comunicación con Android nativo
const MethodChannel _nfcChannel = MethodChannel('com.clickpalm.clickpalmapp/nfc');

/// Resultado de la verificación de NFC
enum NfcStatus {
  available,      // NFC disponible y activado
  disabled,       // NFC disponible pero desactivado
  notSupported,   // Dispositivo no tiene NFC
}

/// Verifica el estado del NFC y muestra alerta si está desactivado
/// Retorna true si NFC está listo para usar, false si no
Future<bool> checkNfcStatus(BuildContext context, {bool showAlert = true}) async {
  try {
    // Verificar si NFC está disponible
    bool isAvailable = await NfcManager.instance.isAvailable();

    if (isAvailable) {
      // NFC está disponible y activado
      return true;
    }

    // NFC no está disponible - puede ser que esté desactivado o no soportado
    // En Android, intentamos abrir los ajustes de NFC
    if (showAlert && context.mounted) {
      final shouldOpenSettings = await NfcDisabledAlertWidget.show(context);

      if (shouldOpenSettings == true) {
        await openNfcSettings();
      }
    }

    return false;
  } catch (e) {
    debugPrint('Error verificando NFC: $e');
    return false;
  }
}

/// Abre los ajustes de NFC del dispositivo
Future<void> openNfcSettings() async {
  try {
    if (Platform.isAndroid) {
      // Intentar usar el MethodChannel para abrir ajustes NFC
      try {
        await _nfcChannel.invokeMethod('openNfcSettings');
        return;
      } catch (e) {
        debugPrint('MethodChannel no disponible, usando fallback: $e');
      }
    }
  } catch (e) {
    debugPrint('Error abriendo ajustes NFC: $e');
  }
}

/// Verifica si el dispositivo tiene hardware NFC
Future<bool> hasNfcHardware() async {
  try {
    // En Android, NfcManager.isAvailable() retorna false tanto si
    // no hay hardware como si está desactivado.
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}
