import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/api_requests/api_manager.dart';
import '/backend/sqlite/sqlite_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'release_log.dart';
import 'safe_struct_hydration.dart';
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
      _isSync = prefs.getBool('ff_isSync') ?? _isSync;
    });
    _safeInit(() {
      _gpsMode = prefs.getString('ff_gpsMode') ?? _gpsMode;
    });
    _safeInit(() {
      final ms = prefs.getInt('ff_lastSyncBase');
      if (ms != null) _lastSyncBase = DateTime.fromMillisecondsSinceEpoch(ms);
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
    _safeInit(() {
      if (prefs.containsKey('ff_userSelected')) {
        final data = safeJsonDecodeMap(
            'userSelected', prefs.getString('ff_userSelected') ?? '');
        _userSelected = safeHydrateUsers(data);
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_companyDefault')) {
        final data = safeJsonDecodeMap(
            'companyDefault', prefs.getString('ff_companyDefault') ?? '');
        _companyDefault = safeHydrateCompanies(data);
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_deviceDefault')) {
        final data = safeJsonDecodeMap(
            'deviceDefault', prefs.getString('ff_deviceDefault') ?? '');
        _deviceDefault = safeHydrateDevices(data);
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_activityDefault')) {
        final data = safeJsonDecodeMap(
            'activityDefault', prefs.getString('ff_activityDefault') ?? '');
        _activityDefault = safeHydrateActivities(data);
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_activitySelected')) {
        final data = safeJsonDecodeMap(
            'activitySelected', prefs.getString('ff_activitySelected') ?? '');
        _activitySelected = safeHydrateActivities(data);
      }
    });
    _safeInit(() {
      _headquartersList = prefs
              .getStringList('ff_headquartersList')
              ?.map((x) => safeHydrateHeadquarters(
                  safeJsonDecodeMap('headquartersList[]', x)))
              .toList() ??
          _headquartersList;
    });
    _safeInit(() {
      _productsList = prefs
              .getStringList('ff_productsList')
              ?.map((x) {
                try {
                  return ProductsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e, st) {
                  releaseLog('hydrate productsList[]', e, st);
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _productsList;
    });
    _safeInit(() {
      _usersList = prefs
              .getStringList('ff_usersList')
              ?.map((x) =>
                  safeHydrateUsers(safeJsonDecodeMap('usersList[]', x)))
              .toList() ??
          _usersList;
    });
    _safeInit(() {
      _zonesList = prefs
              .getStringList('ff_zonesList')
              ?.map((x) {
                try {
                  return ZonesStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _zonesList;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_headquarterSelected')) {
        final data = safeJsonDecodeMap('headquarterSelected',
            prefs.getString('ff_headquarterSelected') ?? '');
        _headquarterSelected = safeHydrateHeadquarters(data);
      }
    });
    _safeInit(() {
      _visitsAdd = prefs
              .getStringList('ff_visitsAdd')
              ?.map((x) {
                try {
                  return VisitsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _visitsAdd;
    });
    _safeInit(() {
      _pathDatabase = prefs.getString('ff_pathDatabase') ?? _pathDatabase;
    });
    _safeInit(() {
      _lastLineInstall = prefs.getInt('ff_lastLineInstall') ?? _lastLineInstall;
    });
    _safeInit(() {
      _lastPalmInstall = prefs.getInt('ff_lastPalmInstall') ?? _lastPalmInstall;
    });
    _safeInit(() {
      _androidID = prefs.getString('ff_androidID') ?? _androidID;
    });
    _safeInit(() {
      _isCalibrateVoice =
          prefs.getBool('ff_isCalibrateVoice') ?? _isCalibrateVoice;
    });
    _safeInit(() {
      _listVoiceCalibration = prefs.getStringList('ff_listVoiceCalibration') ??
          _listVoiceCalibration;
    });
    _safeInit(() {
      _calibrateCompass =
          prefs.getBool('ff_calibrateCompass') ?? _calibrateCompass;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_activitiesJSON')) {
        try {
          _activitiesJSON =
              jsonDecode(prefs.getString('ff_activitiesJSON') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
    _safeInit(() {
      _headquartersSelectedList = prefs
              .getStringList('ff_headquartersSelectedList')
              ?.map((x) => safeHydrateHeadquarters(
                  safeJsonDecodeMap('headquartersSelectedList[]', x)))
              .toList() ??
          _headquartersSelectedList;
    });
    _safeInit(() {
      _newsList = prefs
              .getStringList('ff_newsList')
              ?.map((x) {
                try {
                  return NewsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _newsList;
    });
    _safeInit(() {
      _newsSelected = prefs
              .getStringList('ff_newsSelected')
              ?.map((x) {
                try {
                  return NewsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _newsSelected;
    });
    _safeInit(() {
      if (prefs.containsKey('ff_userSelectedJSON')) {
        try {
          _userSelectedJSON =
              jsonDecode(prefs.getString('ff_userSelectedJSON') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_activitySelectedJSON')) {
        try {
          _activitySelectedJSON =
              jsonDecode(prefs.getString('ff_activitySelectedJSON') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_currentActivity')) {
        try {
          _currentActivity =
              jsonDecode(prefs.getString('ff_currentActivity') ?? '');
        } catch (e) {
          print("Can't decode persisted json. Error: $e.");
        }
      }
    });
    _safeInit(() {
      _activitiesStatusSelected = prefs
              .getStringList('ff_activitiesStatusSelected')
              ?.map((x) {
                try {
                  return ActivitiesStatusStruct.fromSerializableMap(
                      jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _activitiesStatusSelected;
    });
    _safeInit(() {
      _newsAdd = prefs
              .getStringList('ff_newsAdd')
              ?.map((x) {
                try {
                  return VisitsNewsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _newsAdd;
    });
    _safeInit(() {
      _StatusAdd = prefs
              .getStringList('ff_StatusAdd')
              ?.map((x) {
                try {
                  return ActivitiesStatusStruct.fromSerializableMap(
                      jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _StatusAdd;
    });
    _safeInit(() {
      _sp3NavFile = prefs.getString('ff_sp3NavFile') ?? _sp3NavFile;
    });
    _safeInit(() {
      _geoLocationsList = prefs
              .getStringList('ff_geoLocationsList')
              ?.map((x) {
                try {
                  return ReadGeoStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _geoLocationsList;
    });
    _safeInit(() {
      _visitDetails = prefs
              .getStringList('ff_visitDetails')
              ?.map((x) {
                try {
                  return VisitsDetailsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _visitDetails;
    });
    _safeInit(() {
      _pathPmtiles = prefs.getString('ff_pathPmtiles') ?? _pathPmtiles;
    });
    _safeInit(() {
      _hasOrtomosaics = prefs.getBool('ff_hasOrtomosaics') ?? _hasOrtomosaics;
    });
    _safeInit(() {
      _routeConfigStartLine =
          prefs.getInt('ff_routeConfigStartLine') ?? _routeConfigStartLine;
    });
    _safeInit(() {
      _routeConfigStartPoint =
          prefs.getInt('ff_routeConfigStartPoint') ?? _routeConfigStartPoint;
    });
    _safeInit(() {
      _routeConfigMaxLines =
          prefs.getInt('ff_routeConfigMaxLines') ?? _routeConfigMaxLines;
    });
    _safeInit(() {
      _routeConfigMaxPoints =
          prefs.getInt('ff_routeConfigMaxPoints') ?? _routeConfigMaxPoints;
    });
    _safeInit(() {
      _routeConfigPattern =
          prefs.getInt('ff_routeConfigPattern') ?? _routeConfigPattern;
    });
    _safeInit(() {
      _routeConfigErrorMargin = prefs.getDouble('ff_routeConfigErrorMargin') ??
          _routeConfigErrorMargin;
    });

    _logHydrationStatus();
  }

  /// Detecta structs persistidos cuya clave existe en SharedPreferences
  /// pero quedaron deserializados vacíos (jsonDecode falló y _safeInit lo
  /// silenció con el log). Sirve para identificar QUÉ clave quedó corrupta
  /// la próxima vez que el bug aparezca.
  void _logHydrationStatus() {
    void check(String key, bool isEmpty) {
      try {
        if (prefs.containsKey(key) && isEmpty) {
          releaseLog(
              'FFAppState hydration WARN: $key present but struct empty');
        }
      } catch (e, st) {
        releaseLog('FFAppState._logHydrationStatus $key', e, st);
      }
    }

    check('ff_userSelected', !_userSelected.hasIdUser());
    check('ff_companyDefault', !_companyDefault.hasIdCompany());
    check('ff_deviceDefault', !_deviceDefault.hasIdDevice());
    check('ff_activityDefault', !_activityDefault.hasIdActivity());
    check('ff_activitySelected', !_activitySelected.hasIdActivity());
    check('ff_headquarterSelected', !_headquarterSelected.hasIdHeadquarter());
  }

  void update(VoidCallback callback) {
    try {
      callback();
    } catch (e, st) {
      releaseLog('FFAppState.update callback threw', e, st);
    }
    notifyListeners();
  }

  late SharedPreferences prefs;

  String _codeKeyboard = '';
  String get codeKeyboard => _codeKeyboard;
  set codeKeyboard(String value) {
    _codeKeyboard = value;
  }

  bool _isSync = false;
  bool get isSync => _isSync;
  set isSync(bool value) {
    _isSync = value;
    prefs.setBool('ff_isSync', value);
  }

  // Modo GPS activo: 'LITE' (básico, bajo consumo) o 'ADVANCED' (UKF+IMU, preciso).
  // Default ADVANCED para nuevas instalaciones. Reactivo en UI vía notifyListeners.
  String _gpsMode = 'ADVANCED';
  String get gpsMode => _gpsMode;
  set gpsMode(String value) {
    _gpsMode = value;
    prefs.setString('ff_gpsMode', value);
    notifyListeners();
  }

  DateTime? _lastSync = DateTime.fromMillisecondsSinceEpoch(1743526800000);
  DateTime? get lastSync => _lastSync;
  set lastSync(DateTime? value) {
    _lastSync = value;
  }

  // Fecha de la última sincronización de datos base (12 endpoints GZIP).
  // null = nunca sincronizado (primera vez). Persistido en SharedPreferences.
  DateTime? _lastSyncBase;
  DateTime? get lastSyncBase => _lastSyncBase;
  set lastSyncBase(DateTime? value) {
    _lastSyncBase = value;
    if (value != null) {
      prefs.setInt('ff_lastSyncBase', value.millisecondsSinceEpoch);
    } else {
      prefs.remove('ff_lastSyncBase');
    }
  }

  dynamic _loginResponse;
  dynamic get loginResponse => _loginResponse;
  set loginResponse(dynamic value) {
    _loginResponse = value;
    _safeWrite('loginResponse',
        () => prefs.setString('ff_loginResponse', jsonEncode(value)));
  }

  UsersStruct _userSelected = UsersStruct();
  UsersStruct get userSelected => _userSelected;
  set userSelected(UsersStruct value) {
    _userSelected = value;
    _safeWrite('userSelected',
        () => prefs.setString('ff_userSelected', safeSerializeUsers(value)));
  }

  void updateUserSelectedStruct(Function(UsersStruct) updateFn) {
    updateFn(_userSelected);
    _safeWrite(
        'userSelected',
        () => prefs.setString(
            'ff_userSelected', safeSerializeUsers(_userSelected)));
  }

  CompaniesStruct _companyDefault = CompaniesStruct();
  CompaniesStruct get companyDefault => _companyDefault;
  set companyDefault(CompaniesStruct value) {
    _companyDefault = value;
    _safeWrite(
        'companyDefault',
        () => prefs.setString(
            'ff_companyDefault', safeSerializeCompanies(value)));
  }

  void updateCompanyDefaultStruct(Function(CompaniesStruct) updateFn) {
    updateFn(_companyDefault);
    _safeWrite(
        'companyDefault',
        () => prefs.setString(
            'ff_companyDefault', safeSerializeCompanies(_companyDefault)));
  }

  DevicesStruct _deviceDefault = DevicesStruct();
  DevicesStruct get deviceDefault => _deviceDefault;
  set deviceDefault(DevicesStruct value) {
    _deviceDefault = value;
    _safeWrite(
        'deviceDefault',
        () =>
            prefs.setString('ff_deviceDefault', safeSerializeDevices(value)));
  }

  void updateDeviceDefaultStruct(Function(DevicesStruct) updateFn) {
    updateFn(_deviceDefault);
    _safeWrite(
        'deviceDefault',
        () => prefs.setString(
            'ff_deviceDefault', safeSerializeDevices(_deviceDefault)));
  }

  ActivitiesStruct _activityDefault = ActivitiesStruct();
  ActivitiesStruct get activityDefault => _activityDefault;
  set activityDefault(ActivitiesStruct value) {
    _activityDefault = value;
    _safeWrite(
        'activityDefault',
        () => prefs.setString(
            'ff_activityDefault', safeSerializeActivities(value)));
  }

  void updateActivityDefaultStruct(Function(ActivitiesStruct) updateFn) {
    updateFn(_activityDefault);
    _safeWrite(
        'activityDefault',
        () => prefs.setString('ff_activityDefault',
            safeSerializeActivities(_activityDefault)));
  }

  // Actividad seleccionada (STRUCT - reemplaza activitySelectedJSON)
  ActivitiesStruct _activitySelected = ActivitiesStruct();
  ActivitiesStruct get activitySelected => _activitySelected;
  set activitySelected(ActivitiesStruct value) {
    _activitySelected = value;
    _safeWrite(
        'activitySelected',
        () => prefs.setString(
            'ff_activitySelected', safeSerializeActivities(value)));
  }

  void updateActivitySelectedStruct(Function(ActivitiesStruct) updateFn) {
    updateFn(_activitySelected);
    _safeWrite(
        'activitySelected',
        () => prefs.setString('ff_activitySelected',
            safeSerializeActivities(_activitySelected)));
  }

  void clearActivitySelected() {
    _activitySelected = ActivitiesStruct();
    _safeWrite('activitySelected.clear',
        () => prefs.remove('ff_activitySelected'));
  }

  List<HeadquartersStruct> _headquartersList = [];
  List<HeadquartersStruct> get headquartersList => _headquartersList;
  set headquartersList(List<HeadquartersStruct> value) {
    _headquartersList = value;
    _safeWrite(
        'headquartersList',
        () => prefs.setStringList('ff_headquartersList',
            value.map(safeSerializeHeadquarters).toList()));
  }

  void addToHeadquartersList(HeadquartersStruct value) {
    headquartersList.add(value);
    _safeWrite(
        'headquartersList.add',
        () => prefs.setStringList('ff_headquartersList',
            _headquartersList.map(safeSerializeHeadquarters).toList()));
  }

  void removeFromHeadquartersList(HeadquartersStruct value) {
    headquartersList.remove(value);
    _safeWrite(
        'headquartersList.remove',
        () => prefs.setStringList('ff_headquartersList',
            _headquartersList.map(safeSerializeHeadquarters).toList()));
  }

  void removeAtIndexFromHeadquartersList(int index) {
    headquartersList.removeAt(index);
    _safeWrite(
        'headquartersList.removeAt',
        () => prefs.setStringList('ff_headquartersList',
            _headquartersList.map(safeSerializeHeadquarters).toList()));
  }

  void updateHeadquartersListAtIndex(
    int index,
    HeadquartersStruct Function(HeadquartersStruct) updateFn,
  ) {
    headquartersList[index] = updateFn(_headquartersList[index]);
    _safeWrite(
        'headquartersList.updateAt',
        () => prefs.setStringList('ff_headquartersList',
            _headquartersList.map(safeSerializeHeadquarters).toList()));
  }

  void insertAtIndexInHeadquartersList(int index, HeadquartersStruct value) {
    headquartersList.insert(index, value);
    _safeWrite(
        'headquartersList.insert',
        () => prefs.setStringList('ff_headquartersList',
            _headquartersList.map(safeSerializeHeadquarters).toList()));
  }

  List<ProductsStruct> _productsList = [];
  List<ProductsStruct> get productsList => _productsList;
  set productsList(List<ProductsStruct> value) {
    _productsList = value;
    prefs.setStringList(
        'ff_productsList', value.map((x) => x.serialize()).toList());
  }

  void addToProductsList(ProductsStruct value) {
    productsList.add(value);
    prefs.setStringList(
        'ff_productsList', _productsList.map((x) => x.serialize()).toList());
  }

  void removeFromProductsList(ProductsStruct value) {
    productsList.remove(value);
    prefs.setStringList(
        'ff_productsList', _productsList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromProductsList(int index) {
    productsList.removeAt(index);
    prefs.setStringList(
        'ff_productsList', _productsList.map((x) => x.serialize()).toList());
  }

  void updateProductsListAtIndex(
    int index,
    ProductsStruct Function(ProductsStruct) updateFn,
  ) {
    productsList[index] = updateFn(_productsList[index]);
    prefs.setStringList(
        'ff_productsList', _productsList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInProductsList(int index, ProductsStruct value) {
    productsList.insert(index, value);
    prefs.setStringList(
        'ff_productsList', _productsList.map((x) => x.serialize()).toList());
  }

  List<UsersStruct> _usersList = [];
  List<UsersStruct> get usersList => _usersList;
  set usersList(List<UsersStruct> value) {
    _usersList = value;
    _safeWrite(
        'usersList',
        () => prefs.setStringList(
            'ff_usersList', value.map(safeSerializeUsers).toList()));
  }

  void addToUsersList(UsersStruct value) {
    usersList.add(value);
    _safeWrite(
        'usersList.add',
        () => prefs.setStringList(
            'ff_usersList', _usersList.map(safeSerializeUsers).toList()));
  }

  void removeFromUsersList(UsersStruct value) {
    usersList.remove(value);
    _safeWrite(
        'usersList.remove',
        () => prefs.setStringList(
            'ff_usersList', _usersList.map(safeSerializeUsers).toList()));
  }

  void removeAtIndexFromUsersList(int index) {
    usersList.removeAt(index);
    _safeWrite(
        'usersList.removeAt',
        () => prefs.setStringList(
            'ff_usersList', _usersList.map(safeSerializeUsers).toList()));
  }

  void updateUsersListAtIndex(
    int index,
    UsersStruct Function(UsersStruct) updateFn,
  ) {
    usersList[index] = updateFn(_usersList[index]);
    _safeWrite(
        'usersList.updateAt',
        () => prefs.setStringList(
            'ff_usersList', _usersList.map(safeSerializeUsers).toList()));
  }

  void insertAtIndexInUsersList(int index, UsersStruct value) {
    usersList.insert(index, value);
    _safeWrite(
        'usersList.insert',
        () => prefs.setStringList(
            'ff_usersList', _usersList.map(safeSerializeUsers).toList()));
  }

  List<ZonesStruct> _zonesList = [];
  List<ZonesStruct> get zonesList => _zonesList;
  set zonesList(List<ZonesStruct> value) {
    _zonesList = value;
    prefs.setStringList(
        'ff_zonesList', value.map((x) => x.serialize()).toList());
  }

  void addToZonesList(ZonesStruct value) {
    zonesList.add(value);
    prefs.setStringList(
        'ff_zonesList', _zonesList.map((x) => x.serialize()).toList());
  }

  void removeFromZonesList(ZonesStruct value) {
    zonesList.remove(value);
    prefs.setStringList(
        'ff_zonesList', _zonesList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromZonesList(int index) {
    zonesList.removeAt(index);
    prefs.setStringList(
        'ff_zonesList', _zonesList.map((x) => x.serialize()).toList());
  }

  void updateZonesListAtIndex(
    int index,
    ZonesStruct Function(ZonesStruct) updateFn,
  ) {
    zonesList[index] = updateFn(_zonesList[index]);
    prefs.setStringList(
        'ff_zonesList', _zonesList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInZonesList(int index, ZonesStruct value) {
    zonesList.insert(index, value);
    prefs.setStringList(
        'ff_zonesList', _zonesList.map((x) => x.serialize()).toList());
  }

  String _codeSupervisor = '';
  String get codeSupervisor => _codeSupervisor;
  set codeSupervisor(String value) {
    _codeSupervisor = value;
  }

  String _codeOperator = '';
  String get codeOperator => _codeOperator;
  set codeOperator(String value) {
    _codeOperator = value;
  }

  ZonesStruct _zoneSelected = ZonesStruct();
  ZonesStruct get zoneSelected => _zoneSelected;
  set zoneSelected(ZonesStruct value) {
    _zoneSelected = value;
  }

  void updateZoneSelectedStruct(Function(ZonesStruct) updateFn) {
    updateFn(_zoneSelected);
  }

  HeadquartersStruct _headquarterSelected = HeadquartersStruct();
  HeadquartersStruct get headquarterSelected => _headquarterSelected;
  set headquarterSelected(HeadquartersStruct value) {
    _headquarterSelected = value;
    _safeWrite(
        'headquarterSelected',
        () => prefs.setString(
            'ff_headquarterSelected', safeSerializeHeadquarters(value)));
  }

  void updateHeadquarterSelectedStruct(Function(HeadquartersStruct) updateFn) {
    updateFn(_headquarterSelected);
    _safeWrite(
        'headquarterSelected',
        () => prefs.setString('ff_headquarterSelected',
            safeSerializeHeadquarters(_headquarterSelected)));
  }

  List<ProductsStruct> _productsAdd = [];
  List<ProductsStruct> get productsAdd => _productsAdd;
  set productsAdd(List<ProductsStruct> value) {
    _productsAdd = value;
  }

  void addToProductsAdd(ProductsStruct value) {
    productsAdd.add(value);
  }

  void removeFromProductsAdd(ProductsStruct value) {
    productsAdd.remove(value);
  }

  void removeAtIndexFromProductsAdd(int index) {
    productsAdd.removeAt(index);
  }

  void updateProductsAddAtIndex(
    int index,
    ProductsStruct Function(ProductsStruct) updateFn,
  ) {
    productsAdd[index] = updateFn(_productsAdd[index]);
  }

  void insertAtIndexInProductsAdd(int index, ProductsStruct value) {
    productsAdd.insert(index, value);
  }

  List<VisitsStruct> _visitsAdd = [];
  List<VisitsStruct> get visitsAdd => _visitsAdd;
  set visitsAdd(List<VisitsStruct> value) {
    _visitsAdd = value;
    prefs.setStringList(
        'ff_visitsAdd', value.map((x) => x.serialize()).toList());
  }

  void addToVisitsAdd(VisitsStruct value) {
    visitsAdd.add(value);
    prefs.setStringList(
        'ff_visitsAdd', _visitsAdd.map((x) => x.serialize()).toList());
  }

  void removeFromVisitsAdd(VisitsStruct value) {
    visitsAdd.remove(value);
    prefs.setStringList(
        'ff_visitsAdd', _visitsAdd.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromVisitsAdd(int index) {
    visitsAdd.removeAt(index);
    prefs.setStringList(
        'ff_visitsAdd', _visitsAdd.map((x) => x.serialize()).toList());
  }

  void updateVisitsAddAtIndex(
    int index,
    VisitsStruct Function(VisitsStruct) updateFn,
  ) {
    visitsAdd[index] = updateFn(_visitsAdd[index]);
    prefs.setStringList(
        'ff_visitsAdd', _visitsAdd.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInVisitsAdd(int index, VisitsStruct value) {
    visitsAdd.insert(index, value);
    prefs.setStringList(
        'ff_visitsAdd', _visitsAdd.map((x) => x.serialize()).toList());
  }

  dynamic _activitySelectedJSON;
  dynamic get activitySelectedJSON => _activitySelectedJSON;
  set activitySelectedJSON(dynamic value) {
    _activitySelectedJSON = value;
    _safeWrite(
        'activitySelectedJSON',
        () => prefs.setString(
            'ff_activitySelectedJSON', jsonEncode(value)));
  }

  String _pathDatabase = '';
  String get pathDatabase => _pathDatabase;
  set pathDatabase(String value) {
    _pathDatabase = value;
    prefs.setString('ff_pathDatabase', value);
  }

  int _lastLineInstall = 0;
  int get lastLineInstall => _lastLineInstall;
  set lastLineInstall(int value) {
    _lastLineInstall = value;
    prefs.setInt('ff_lastLineInstall', value);
  }

  int _lastPalmInstall = 0;
  int get lastPalmInstall => _lastPalmInstall;
  set lastPalmInstall(int value) {
    _lastPalmInstall = value;
    prefs.setInt('ff_lastPalmInstall', value);
  }

  String _androidID = '';
  String get androidID => _androidID;
  set androidID(String value) {
    _androidID = value;
    prefs.setString('ff_androidID', value);
  }

  bool _stopVoice = false;
  bool get stopVoice => _stopVoice;
  set stopVoice(bool value) {
    _stopVoice = value;
  }

  // Variable para guardar la preferencia de generar ruta óptima durante la sesión
  // null = no se ha preguntado aún, true/false = preferencia guardada
  // NO se persiste para que se resetee al reiniciar la app
  bool? _shouldGenerateOptimalRoute;
  bool? get shouldGenerateOptimalRoute => _shouldGenerateOptimalRoute;
  set shouldGenerateOptimalRoute(bool? value) {
    _shouldGenerateOptimalRoute = value;
  }

  bool _isCalibrateVoice = false;
  bool get isCalibrateVoice => _isCalibrateVoice;
  set isCalibrateVoice(bool value) {
    _isCalibrateVoice = value;
    prefs.setBool('ff_isCalibrateVoice', value);
  }

  List<String> _listVoiceCalibration = [];
  List<String> get listVoiceCalibration => _listVoiceCalibration;
  set listVoiceCalibration(List<String> value) {
    _listVoiceCalibration = value;
    prefs.setStringList('ff_listVoiceCalibration', value);
  }

  void addToListVoiceCalibration(String value) {
    listVoiceCalibration.add(value);
    prefs.setStringList('ff_listVoiceCalibration', _listVoiceCalibration);
  }

  void removeFromListVoiceCalibration(String value) {
    listVoiceCalibration.remove(value);
    prefs.setStringList('ff_listVoiceCalibration', _listVoiceCalibration);
  }

  void removeAtIndexFromListVoiceCalibration(int index) {
    listVoiceCalibration.removeAt(index);
    prefs.setStringList('ff_listVoiceCalibration', _listVoiceCalibration);
  }

  void updateListVoiceCalibrationAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    listVoiceCalibration[index] = updateFn(_listVoiceCalibration[index]);
    prefs.setStringList('ff_listVoiceCalibration', _listVoiceCalibration);
  }

  void insertAtIndexInListVoiceCalibration(int index, String value) {
    listVoiceCalibration.insert(index, value);
    prefs.setStringList('ff_listVoiceCalibration', _listVoiceCalibration);
  }

  int _idActivityStatus = 0;
  int get idActivityStatus => _idActivityStatus;
  set idActivityStatus(int value) {
    _idActivityStatus = value;
  }

  bool _calibrateCompass = false;
  bool get calibrateCompass => _calibrateCompass;
  set calibrateCompass(bool value) {
    _calibrateCompass = value;
    prefs.setBool('ff_calibrateCompass', value);
  }

  String _nfcRead = '';
  String get nfcRead => _nfcRead;
  set nfcRead(String value) {
    _nfcRead = value;
  }

  String _nfcHardwareTagId = '';
  String get nfcHardwareTagId => _nfcHardwareTagId;
  set nfcHardwareTagId(String value) {
    _nfcHardwareTagId = value;
  }

  String _nfcLastProductName = '';
  String get nfcLastProductName => _nfcLastProductName;
  set nfcLastProductName(String value) {
    _nfcLastProductName = value;
  }

  dynamic _activitiesJSON;
  dynamic get activitiesJSON => _activitiesJSON;
  set activitiesJSON(dynamic value) {
    _activitiesJSON = value;
    _safeWrite('activitiesJSON',
        () => prefs.setString('ff_activitiesJSON', jsonEncode(value)));
  }

  dynamic _activityStatusSelectedJSON;
  dynamic get activityStatusSelectedJSON => _activityStatusSelectedJSON;
  set activityStatusSelectedJSON(dynamic value) {
    _activityStatusSelectedJSON = value;
  }

  String _qrRead = '';
  String get qrRead => _qrRead;
  set qrRead(String value) {
    _qrRead = value;
  }

  List<HeadquartersStruct> _headquartersSelectedList = [];
  List<HeadquartersStruct> get headquartersSelectedList =>
      _headquartersSelectedList;
  set headquartersSelectedList(List<HeadquartersStruct> value) {
    _headquartersSelectedList = value;
    _safeWrite(
        'headquartersSelectedList',
        () => prefs.setStringList('ff_headquartersSelectedList',
            value.map(safeSerializeHeadquarters).toList()));
  }

  void addToHeadquartersSelectedList(HeadquartersStruct value) {
    headquartersSelectedList.add(value);
    _safeWrite(
        'headquartersSelectedList.add',
        () => prefs.setStringList(
            'ff_headquartersSelectedList',
            _headquartersSelectedList
                .map(safeSerializeHeadquarters)
                .toList()));
  }

  void removeFromHeadquartersSelectedList(HeadquartersStruct value) {
    headquartersSelectedList.remove(value);
    _safeWrite(
        'headquartersSelectedList.remove',
        () => prefs.setStringList(
            'ff_headquartersSelectedList',
            _headquartersSelectedList
                .map(safeSerializeHeadquarters)
                .toList()));
  }

  void removeAtIndexFromHeadquartersSelectedList(int index) {
    headquartersSelectedList.removeAt(index);
    _safeWrite(
        'headquartersSelectedList.removeAt',
        () => prefs.setStringList(
            'ff_headquartersSelectedList',
            _headquartersSelectedList
                .map(safeSerializeHeadquarters)
                .toList()));
  }

  void updateHeadquartersSelectedListAtIndex(
    int index,
    HeadquartersStruct Function(HeadquartersStruct) updateFn,
  ) {
    headquartersSelectedList[index] =
        updateFn(_headquartersSelectedList[index]);
    _safeWrite(
        'headquartersSelectedList.updateAt',
        () => prefs.setStringList(
            'ff_headquartersSelectedList',
            _headquartersSelectedList
                .map(safeSerializeHeadquarters)
                .toList()));
  }

  void insertAtIndexInHeadquartersSelectedList(
      int index, HeadquartersStruct value) {
    headquartersSelectedList.insert(index, value);
    _safeWrite(
        'headquartersSelectedList.insert',
        () => prefs.setStringList(
            'ff_headquartersSelectedList',
            _headquartersSelectedList
                .map(safeSerializeHeadquarters)
                .toList()));
  }

  List<NewsStruct> _newsList = [];
  List<NewsStruct> get newsList => _newsList;
  set newsList(List<NewsStruct> value) {
    _newsList = value;
    prefs.setStringList(
        'ff_newsList', value.map((x) => x.serialize()).toList());
  }

  void addToNewsList(NewsStruct value) {
    newsList.add(value);
    prefs.setStringList(
        'ff_newsList', _newsList.map((x) => x.serialize()).toList());
  }

  void removeFromNewsList(NewsStruct value) {
    newsList.remove(value);
    prefs.setStringList(
        'ff_newsList', _newsList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromNewsList(int index) {
    newsList.removeAt(index);
    prefs.setStringList(
        'ff_newsList', _newsList.map((x) => x.serialize()).toList());
  }

  void updateNewsListAtIndex(
    int index,
    NewsStruct Function(NewsStruct) updateFn,
  ) {
    newsList[index] = updateFn(_newsList[index]);
    prefs.setStringList(
        'ff_newsList', _newsList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInNewsList(int index, NewsStruct value) {
    newsList.insert(index, value);
    prefs.setStringList(
        'ff_newsList', _newsList.map((x) => x.serialize()).toList());
  }

  List<NewsStruct> _newsSelected = [];
  List<NewsStruct> get newsSelected => _newsSelected;
  set newsSelected(List<NewsStruct> value) {
    _newsSelected = value;
    prefs.setStringList(
        'ff_newsSelected', value.map((x) => x.serialize()).toList());
  }

  void addToNewsSelected(NewsStruct value) {
    newsSelected.add(value);
    prefs.setStringList(
        'ff_newsSelected', _newsSelected.map((x) => x.serialize()).toList());
  }

  void removeFromNewsSelected(NewsStruct value) {
    newsSelected.remove(value);
    prefs.setStringList(
        'ff_newsSelected', _newsSelected.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromNewsSelected(int index) {
    newsSelected.removeAt(index);
    prefs.setStringList(
        'ff_newsSelected', _newsSelected.map((x) => x.serialize()).toList());
  }

  void updateNewsSelectedAtIndex(
    int index,
    NewsStruct Function(NewsStruct) updateFn,
  ) {
    newsSelected[index] = updateFn(_newsSelected[index]);
    prefs.setStringList(
        'ff_newsSelected', _newsSelected.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInNewsSelected(int index, NewsStruct value) {
    newsSelected.insert(index, value);
    prefs.setStringList(
        'ff_newsSelected', _newsSelected.map((x) => x.serialize()).toList());
  }

  String _moduleSelected = '';
  String get moduleSelected => _moduleSelected;
  set moduleSelected(String value) {
    _moduleSelected = value;
  }

  dynamic _userSelectedJSON;
  dynamic get userSelectedJSON => _userSelectedJSON;
  set userSelectedJSON(dynamic value) {
    _userSelectedJSON = value;
    _safeWrite('userSelectedJSON',
        () => prefs.setString('ff_userSelectedJSON', jsonEncode(value)));
  }

  List<ActivitiesStatusStruct> _activitiesStatusSelected = [];
  List<ActivitiesStatusStruct> get activitiesStatusSelected =>
      _activitiesStatusSelected;
  set activitiesStatusSelected(List<ActivitiesStatusStruct> value) {
    _activitiesStatusSelected = value;
    prefs.setStringList('ff_activitiesStatusSelected',
        value.map((x) => x.serialize()).toList());
  }

  void addToActivitiesStatusSelected(ActivitiesStatusStruct value) {
    activitiesStatusSelected.add(value);
    prefs.setStringList('ff_activitiesStatusSelected',
        _activitiesStatusSelected.map((x) => x.serialize()).toList());
  }

  void removeFromActivitiesStatusSelected(ActivitiesStatusStruct value) {
    activitiesStatusSelected.remove(value);
    prefs.setStringList('ff_activitiesStatusSelected',
        _activitiesStatusSelected.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromActivitiesStatusSelected(int index) {
    activitiesStatusSelected.removeAt(index);
    prefs.setStringList('ff_activitiesStatusSelected',
        _activitiesStatusSelected.map((x) => x.serialize()).toList());
  }

  void updateActivitiesStatusSelectedAtIndex(
    int index,
    ActivitiesStatusStruct Function(ActivitiesStatusStruct) updateFn,
  ) {
    activitiesStatusSelected[index] =
        updateFn(_activitiesStatusSelected[index]);
    prefs.setStringList('ff_activitiesStatusSelected',
        _activitiesStatusSelected.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInActivitiesStatusSelected(
      int index, ActivitiesStatusStruct value) {
    activitiesStatusSelected.insert(index, value);
    prefs.setStringList('ff_activitiesStatusSelected',
        _activitiesStatusSelected.map((x) => x.serialize()).toList());
  }

  List<VisitsNewsStruct> _newsAdd = [];
  List<VisitsNewsStruct> get newsAdd => _newsAdd;
  set newsAdd(List<VisitsNewsStruct> value) {
    _newsAdd = value;
    prefs.setStringList('ff_newsAdd', value.map((x) => x.serialize()).toList());
  }

  void addToNewsAdd(VisitsNewsStruct value) {
    newsAdd.add(value);
    prefs.setStringList(
        'ff_newsAdd', _newsAdd.map((x) => x.serialize()).toList());
  }

  void removeFromNewsAdd(VisitsNewsStruct value) {
    newsAdd.remove(value);
    prefs.setStringList(
        'ff_newsAdd', _newsAdd.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromNewsAdd(int index) {
    newsAdd.removeAt(index);
    prefs.setStringList(
        'ff_newsAdd', _newsAdd.map((x) => x.serialize()).toList());
  }

  void updateNewsAddAtIndex(
    int index,
    VisitsNewsStruct Function(VisitsNewsStruct) updateFn,
  ) {
    newsAdd[index] = updateFn(_newsAdd[index]);
    prefs.setStringList(
        'ff_newsAdd', _newsAdd.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInNewsAdd(int index, VisitsNewsStruct value) {
    newsAdd.insert(index, value);
    prefs.setStringList(
        'ff_newsAdd', _newsAdd.map((x) => x.serialize()).toList());
  }

  List<ActivitiesStatusStruct> _StatusAdd = [];
  List<ActivitiesStatusStruct> get StatusAdd => _StatusAdd;
  set StatusAdd(List<ActivitiesStatusStruct> value) {
    _StatusAdd = value;
    prefs.setStringList(
        'ff_StatusAdd', value.map((x) => x.serialize()).toList());
  }

  void addToStatusAdd(ActivitiesStatusStruct value) {
    StatusAdd.add(value);
    prefs.setStringList(
        'ff_StatusAdd', _StatusAdd.map((x) => x.serialize()).toList());
  }

  void removeFromStatusAdd(ActivitiesStatusStruct value) {
    StatusAdd.remove(value);
    prefs.setStringList(
        'ff_StatusAdd', _StatusAdd.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromStatusAdd(int index) {
    StatusAdd.removeAt(index);
    prefs.setStringList(
        'ff_StatusAdd', _StatusAdd.map((x) => x.serialize()).toList());
  }

  void updateStatusAddAtIndex(
    int index,
    ActivitiesStatusStruct Function(ActivitiesStatusStruct) updateFn,
  ) {
    StatusAdd[index] = updateFn(_StatusAdd[index]);
    prefs.setStringList(
        'ff_StatusAdd', _StatusAdd.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInStatusAdd(int index, ActivitiesStatusStruct value) {
    StatusAdd.insert(index, value);
    prefs.setStringList(
        'ff_StatusAdd', _StatusAdd.map((x) => x.serialize()).toList());
  }

  String _sp3NavFile = '';
  String get sp3NavFile => _sp3NavFile;
  set sp3NavFile(String value) {
    _sp3NavFile = value;
    prefs.setString('ff_sp3NavFile', value);
  }

  List<ReadGeoStruct> _geoLocationsList = [];
  List<ReadGeoStruct> get geoLocationsList => _geoLocationsList;
  set geoLocationsList(List<ReadGeoStruct> value) {
    _geoLocationsList = value;
    prefs.setStringList(
        'ff_geoLocationsList', value.map((x) => x.serialize()).toList());
  }

  void addToGeoLocationsList(ReadGeoStruct value) {
    geoLocationsList.add(value);
    prefs.setStringList('ff_geoLocationsList',
        _geoLocationsList.map((x) => x.serialize()).toList());
  }

  void removeFromGeoLocationsList(ReadGeoStruct value) {
    geoLocationsList.remove(value);
    prefs.setStringList('ff_geoLocationsList',
        _geoLocationsList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromGeoLocationsList(int index) {
    geoLocationsList.removeAt(index);
    prefs.setStringList('ff_geoLocationsList',
        _geoLocationsList.map((x) => x.serialize()).toList());
  }

  void updateGeoLocationsListAtIndex(
    int index,
    ReadGeoStruct Function(ReadGeoStruct) updateFn,
  ) {
    geoLocationsList[index] = updateFn(_geoLocationsList[index]);
    prefs.setStringList('ff_geoLocationsList',
        _geoLocationsList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInGeoLocationsList(int index, ReadGeoStruct value) {
    geoLocationsList.insert(index, value);
    prefs.setStringList('ff_geoLocationsList',
        _geoLocationsList.map((x) => x.serialize()).toList());
  }

  List<VisitsDetailsStruct> _visitDetails = [];
  List<VisitsDetailsStruct> get visitDetails => _visitDetails;
  set visitDetails(List<VisitsDetailsStruct> value) {
    _visitDetails = value;
    prefs.setStringList(
        'ff_visitDetails', value.map((x) => x.serialize()).toList());
  }

  void addToVisitDetails(VisitsDetailsStruct value) {
    visitDetails.add(value);
    prefs.setStringList(
        'ff_visitDetails', _visitDetails.map((x) => x.serialize()).toList());
  }

  void removeFromVisitDetails(VisitsDetailsStruct value) {
    visitDetails.remove(value);
    prefs.setStringList(
        'ff_visitDetails', _visitDetails.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromVisitDetails(int index) {
    visitDetails.removeAt(index);
    prefs.setStringList(
        'ff_visitDetails', _visitDetails.map((x) => x.serialize()).toList());
  }

  void updateVisitDetailsAtIndex(
    int index,
    VisitsDetailsStruct Function(VisitsDetailsStruct) updateFn,
  ) {
    visitDetails[index] = updateFn(_visitDetails[index]);
    prefs.setStringList(
        'ff_visitDetails', _visitDetails.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInVisitDetails(int index, VisitsDetailsStruct value) {
    visitDetails.insert(index, value);
    prefs.setStringList(
        'ff_visitDetails', _visitDetails.map((x) => x.serialize()).toList());
  }

  bool _isStabilized = false;
  bool get isStabilized => _isStabilized;
  set isStabilized(bool value) {
    _isStabilized = value;
    notifyListeners();
  }

  int _totalStepsActivity = 0;
  int get totalStepsActivity => _totalStepsActivity;
  set totalStepsActivity(int value) {
    _totalStepsActivity = value;
  }

  int _countStepsActivity = 0;
  int get countStepsActivity => _countStepsActivity;
  set countStepsActivity(int value) {
    _countStepsActivity = value;
  }

  dynamic _currentActivity;
  dynamic get currentActivity => _currentActivity;
  set currentActivity(dynamic value) {
    _currentActivity = value;
    _safeWrite('currentActivity',
        () => prefs.setString('ff_currentActivity', jsonEncode(value)));
  }

  int _visitCount = 0;
  int get visitCount => _visitCount;
  set visitCount(int value) {
    _visitCount = value;
  }

  String _pathPmtiles = ' ';
  String get pathPmtiles => _pathPmtiles;
  set pathPmtiles(String value) {
    _pathPmtiles = value;
    prefs.setString('ff_pathPmtiles', value);
  }

  bool _hasOrtomosaics = false;
  bool get hasOrtomosaics => _hasOrtomosaics;
  set hasOrtomosaics(bool value) {
    _hasOrtomosaics = value;
    prefs.setBool('ff_hasOrtomosaics', value);
  }

  int _routeConfigStartLine = 0;
  int get routeConfigStartLine => _routeConfigStartLine;
  set routeConfigStartLine(int value) {
    _routeConfigStartLine = value;
    prefs.setInt('ff_routeConfigStartLine', value);
  }

  int _routeConfigStartPoint = 0;
  int get routeConfigStartPoint => _routeConfigStartPoint;
  set routeConfigStartPoint(int value) {
    _routeConfigStartPoint = value;
    prefs.setInt('ff_routeConfigStartPoint', value);
  }

  int _routeConfigMaxLines = 0;
  int get routeConfigMaxLines => _routeConfigMaxLines;
  set routeConfigMaxLines(int value) {
    _routeConfigMaxLines = value;
    prefs.setInt('ff_routeConfigMaxLines', value);
  }

  int _routeConfigMaxPoints = 0;
  int get routeConfigMaxPoints => _routeConfigMaxPoints;
  set routeConfigMaxPoints(int value) {
    _routeConfigMaxPoints = value;
    prefs.setInt('ff_routeConfigMaxPoints', value);
  }

  int _routeConfigPattern = 0;
  int get routeConfigPattern => _routeConfigPattern;
  set routeConfigPattern(int value) {
    _routeConfigPattern = value;
    prefs.setInt('ff_routeConfigPattern', value);
  }

  double _routeConfigErrorMargin = 0.0;
  double get routeConfigErrorMargin => _routeConfigErrorMargin;
  set routeConfigErrorMargin(double value) {
    _routeConfigErrorMargin = value;
    prefs.setDouble('ff_routeConfigErrorMargin', value);
  }

  String _printerMacAddress = '';
  String get printerMacAddress => _printerMacAddress;
  set printerMacAddress(String value) {
    _printerMacAddress = value;
  }

  String _printerName = '';
  String get printerName => _printerName;
  set printerName(String value) {
    _printerName = value;
  }

  // Caché temporal del formulario (no persistido)
  Map<String, dynamic> _formCacheMap = {};
  Map<String, dynamic> get formCacheMap => _formCacheMap;
  set formCacheMap(Map<String, dynamic> value) {
    _formCacheMap = value;
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (e, st) {
    releaseLog('FFAppState._safeInit failed', e, st);
  }
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (e, st) {
    releaseLog('FFAppState._safeInitAsync failed', e, st);
  }
}

/// Envuelve una escritura a SharedPreferences (incluida la serialización
/// del valor) en try/catch para que un fallo de persistencia nunca tumbe
/// al caller. Conserva el estado en memoria y registra el error.
void _safeWrite(String tag, void Function() write) {
  try {
    write();
  } catch (e, st) {
    releaseLog('FFAppState.persist $tag', e, st);
  }
}
