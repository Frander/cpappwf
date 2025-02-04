import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';

String concatenateStrings(
  String string1,
  String string2,
) {
  return '$string1$string2';
}

String removeLastCharacter(String input) {
  if (input.isNotEmpty) {
    return input.substring(0, input.length - 1);
  }
  return input; // Devuelve la cadena original si está vacía.
}

bool validateLocationFormat(String response) {
  // Expresión regular para validar el formato "LAT:XXXXX;LON:XXXXX;ALT:XXXXXX"
  final RegExp regex =
      RegExp(r'^LAT:-?\d+(\.\d+)?;LON:-?\d+(\.\d+)?;ALT:-?\d+(\.\d+)?$');

  // Verificar si la respuesta coincide con el formato
  return regex.hasMatch(response);
}

bool hasMoreThanAnHourPassed(
  DateTime dateStart,
  DateTime dateFinish,
) {
// Calcula la diferencia entre las fechas
  Duration difference = dateFinish.difference(dateStart);

  // Extrae días, horas y minutos
  int days = difference.inDays;
  int hours = difference.inHours % 24; // Horas restantes después de días
  int minutes = difference.inMinutes % 60; // Minutos restantes después de horas

  // Imprime el tiempo transcurrido (opcional para depuración)
  debugPrint("Han pasado $days días, $hours horas y $minutes minutos.");

  // Retorna true si ha pasado más de 1 hora
  return difference.inHours >= 1;
}
