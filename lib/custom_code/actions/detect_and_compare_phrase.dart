// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/components/calculate_coordenates_component_widget.dart';

import '/custom_code/actions/index.dart'
    as actions; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'
    as functions; // Imports custom functions

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:string_similarity/string_similarity.dart';

/// Función que detecta la voz, evalúa la frase y la compara con [validPhrases].
/// Si se cumple el tiempo de `pauseFor`, el servicio se reinicia automáticamente.
/// Se reinicia la escucha solo si `FFAppState().stopVoice` es `false`.
Future<String> detectAndComparePhrase(
    BuildContext context, List<String> validPhrases) async {
  stt.SpeechToText speech = stt.SpeechToText();
  Completer<String> completer = Completer<String>();

  // Declaramos startListening antes de usarla.
  late void Function() startListening;

  bool available = await speech.initialize(
    onStatus: (status) {
      print('Status: $status');
      Future.delayed(Duration(milliseconds: 500), () {
        if (!FFAppState().stopVoice && status == "notListening") {
          print("Restarting speech recognition after pauseFor timeout...");
          startListening();
        }
      });
    },
    onError: (error) {
      print('Error: $error');
      // Si el error es "error_no_match", lo ignoramos y no reiniciamos
      if (error.toString().contains("error_no_match")) {
        print("Ignoring error_no_match.");
        return;
      }
      Future.delayed(Duration(milliseconds: 500), () {
        if (!FFAppState().stopVoice) {
          print("Restarting speech recognition after error...");
          startListening();
        }
      });
    },
  );

  if (!available) {
    print('Speech recognition is not available.');
    return "";
  }

  startListening = () {
    if (!speech.isListening) {
      speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            String recognizedText = result.recognizedWords;
            print('Recognized phrase: $recognizedText');

            for (String phrase in validPhrases) {
              if (phrase.trim().toLowerCase() ==
                  recognizedText.trim().toLowerCase()) {
                // Detenemos la escucha y evitamos reinicios automáticos.
                speech.stop();
                FFAppState().stopVoice = true;

                // Llamar a la función speakText.
                actions.speakText("Opción seleccionada");

                // Mostrar el cuadro de diálogo con el componente embebido.
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (dialogContext) {
                    return Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      alignment: AlignmentDirectional(0.0, 0.0)
                          .resolve(Directionality.of(context)),
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(dialogContext).unfocus();
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.9,
                          width: MediaQuery.sizeOf(context).width * 0.9,
                          child: CalculateCoordenatesComponentWidget(),
                        ),
                      ),
                    );
                  },
                ).then((_) {
                  // Al cerrarse el diálogo, reactivamos el servicio de voz y reiniciamos la escucha.
                  FFAppState().stopVoice = false;
                  startListening();
                });

                completer.complete(phrase);
                return;
              }
            }
            print("Phrase not valid, continuing...");
          }
        },
        listenFor: Duration(seconds: 15),
        pauseFor: Duration(seconds: 5),
        partialResults: false,
        localeId: "es_ES",
      );
    }
  };

  startListening();
  return completer.future;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
