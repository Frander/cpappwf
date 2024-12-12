import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'dart:convert';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _LastSync = prefs.containsKey('ff_LastSync')
          ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt('ff_LastSync')!)
          : _LastSync;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_loginResponse')) {
        try {
          _loginResponse =
              jsonDecode(prefs.getString('ff_loginResponse') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  DateTime? _LastSync;
  DateTime? get LastSync => _LastSync;
  set LastSync(DateTime? value) {
    _LastSync = value;
    value != null
        ? prefs.setInt('ff_LastSync', value.millisecondsSinceEpoch)
        : prefs.remove('ff_LastSync');
  }

  dynamic _loginResponse;
  dynamic get loginResponse => _loginResponse;
  set loginResponse(dynamic value) {
    _loginResponse = value;
    prefs.setString('ff_loginResponse', jsonEncode(value));
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
