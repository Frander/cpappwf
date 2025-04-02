import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

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
      _lastSync = prefs.containsKey('ff_lastSync')
          ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt('ff_lastSync')!)
          : _lastSync;
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
        try {
          final serializedData = prefs.getString('ff_userSelected') ?? '{}';
          _userSelected =
              UsersStruct.fromSerializableMap(jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_companyDefault')) {
        try {
          final serializedData = prefs.getString('ff_companyDefault') ?? '{}';
          _companyDefault =
              CompaniesStruct.fromSerializableMap(jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_deviceDefault')) {
        try {
          final serializedData = prefs.getString('ff_deviceDefault') ?? '{}';
          _deviceDefault =
              DevicesStruct.fromSerializableMap(jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    _safeInit(() {
      _activitiesList = prefs
              .getStringList('ff_activitiesList')
              ?.map((x) {
                try {
                  return ActivitiesStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _activitiesList;
    });
    _safeInit(() {
      _headquartersList = prefs
              .getStringList('ff_headquartersList')
              ?.map((x) {
                try {
                  return HeadquartersStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _headquartersList;
    });
    _safeInit(() {
      _productsList = prefs
              .getStringList('ff_productsList')
              ?.map((x) {
                try {
                  return ProductsStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
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
              ?.map((x) {
                try {
                  return UsersStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
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
        try {
          final serializedData =
              prefs.getString('ff_headquarterSelected') ?? '{}';
          _headquarterSelected = HeadquartersStruct.fromSerializableMap(
              jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
      }
    });
    _safeInit(() {
      if (prefs.containsKey('ff_activitySelected')) {
        try {
          final serializedData = prefs.getString('ff_activitySelected') ?? '{}';
          _activitySelected =
              ActivitiesStruct.fromSerializableMap(jsonDecode(serializedData));
        } catch (e) {
          print("Can't decode persisted data type. Error: $e.");
        }
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
  }

  void update(VoidCallback callback) {
    callback();
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

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;
  set lastSync(DateTime? value) {
    _lastSync = value;
    value != null
        ? prefs.setInt('ff_lastSync', value.millisecondsSinceEpoch)
        : prefs.remove('ff_lastSync');
  }

  dynamic _loginResponse;
  dynamic get loginResponse => _loginResponse;
  set loginResponse(dynamic value) {
    _loginResponse = value;
    prefs.setString('ff_loginResponse', jsonEncode(value));
  }

  UsersStruct _userSelected = UsersStruct();
  UsersStruct get userSelected => _userSelected;
  set userSelected(UsersStruct value) {
    _userSelected = value;
    prefs.setString('ff_userSelected', value.serialize());
  }

  void updateUserSelectedStruct(Function(UsersStruct) updateFn) {
    updateFn(_userSelected);
    prefs.setString('ff_userSelected', _userSelected.serialize());
  }

  CompaniesStruct _companyDefault = CompaniesStruct();
  CompaniesStruct get companyDefault => _companyDefault;
  set companyDefault(CompaniesStruct value) {
    _companyDefault = value;
    prefs.setString('ff_companyDefault', value.serialize());
  }

  void updateCompanyDefaultStruct(Function(CompaniesStruct) updateFn) {
    updateFn(_companyDefault);
    prefs.setString('ff_companyDefault', _companyDefault.serialize());
  }

  DevicesStruct _deviceDefault = DevicesStruct();
  DevicesStruct get deviceDefault => _deviceDefault;
  set deviceDefault(DevicesStruct value) {
    _deviceDefault = value;
    prefs.setString('ff_deviceDefault', value.serialize());
  }

  void updateDeviceDefaultStruct(Function(DevicesStruct) updateFn) {
    updateFn(_deviceDefault);
    prefs.setString('ff_deviceDefault', _deviceDefault.serialize());
  }

  List<ActivitiesStruct> _activitiesList = [];
  List<ActivitiesStruct> get activitiesList => _activitiesList;
  set activitiesList(List<ActivitiesStruct> value) {
    _activitiesList = value;
    prefs.setStringList(
        'ff_activitiesList', value.map((x) => x.serialize()).toList());
  }

  void addToActivitiesList(ActivitiesStruct value) {
    activitiesList.add(value);
    prefs.setStringList('ff_activitiesList',
        _activitiesList.map((x) => x.serialize()).toList());
  }

  void removeFromActivitiesList(ActivitiesStruct value) {
    activitiesList.remove(value);
    prefs.setStringList('ff_activitiesList',
        _activitiesList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromActivitiesList(int index) {
    activitiesList.removeAt(index);
    prefs.setStringList('ff_activitiesList',
        _activitiesList.map((x) => x.serialize()).toList());
  }

  void updateActivitiesListAtIndex(
    int index,
    ActivitiesStruct Function(ActivitiesStruct) updateFn,
  ) {
    activitiesList[index] = updateFn(_activitiesList[index]);
    prefs.setStringList('ff_activitiesList',
        _activitiesList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInActivitiesList(int index, ActivitiesStruct value) {
    activitiesList.insert(index, value);
    prefs.setStringList('ff_activitiesList',
        _activitiesList.map((x) => x.serialize()).toList());
  }

  List<HeadquartersStruct> _headquartersList = [];
  List<HeadquartersStruct> get headquartersList => _headquartersList;
  set headquartersList(List<HeadquartersStruct> value) {
    _headquartersList = value;
    prefs.setStringList(
        'ff_headquartersList', value.map((x) => x.serialize()).toList());
  }

  void addToHeadquartersList(HeadquartersStruct value) {
    headquartersList.add(value);
    prefs.setStringList('ff_headquartersList',
        _headquartersList.map((x) => x.serialize()).toList());
  }

  void removeFromHeadquartersList(HeadquartersStruct value) {
    headquartersList.remove(value);
    prefs.setStringList('ff_headquartersList',
        _headquartersList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromHeadquartersList(int index) {
    headquartersList.removeAt(index);
    prefs.setStringList('ff_headquartersList',
        _headquartersList.map((x) => x.serialize()).toList());
  }

  void updateHeadquartersListAtIndex(
    int index,
    HeadquartersStruct Function(HeadquartersStruct) updateFn,
  ) {
    headquartersList[index] = updateFn(_headquartersList[index]);
    prefs.setStringList('ff_headquartersList',
        _headquartersList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInHeadquartersList(int index, HeadquartersStruct value) {
    headquartersList.insert(index, value);
    prefs.setStringList('ff_headquartersList',
        _headquartersList.map((x) => x.serialize()).toList());
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
    prefs.setStringList(
        'ff_usersList', value.map((x) => x.serialize()).toList());
  }

  void addToUsersList(UsersStruct value) {
    usersList.add(value);
    prefs.setStringList(
        'ff_usersList', _usersList.map((x) => x.serialize()).toList());
  }

  void removeFromUsersList(UsersStruct value) {
    usersList.remove(value);
    prefs.setStringList(
        'ff_usersList', _usersList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromUsersList(int index) {
    usersList.removeAt(index);
    prefs.setStringList(
        'ff_usersList', _usersList.map((x) => x.serialize()).toList());
  }

  void updateUsersListAtIndex(
    int index,
    UsersStruct Function(UsersStruct) updateFn,
  ) {
    usersList[index] = updateFn(_usersList[index]);
    prefs.setStringList(
        'ff_usersList', _usersList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInUsersList(int index, UsersStruct value) {
    usersList.insert(index, value);
    prefs.setStringList(
        'ff_usersList', _usersList.map((x) => x.serialize()).toList());
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
    prefs.setString('ff_headquarterSelected', value.serialize());
  }

  void updateHeadquarterSelectedStruct(Function(HeadquartersStruct) updateFn) {
    updateFn(_headquarterSelected);
    prefs.setString('ff_headquarterSelected', _headquarterSelected.serialize());
  }

  ActivitiesStruct _activitySelected = ActivitiesStruct();
  ActivitiesStruct get activitySelected => _activitySelected;
  set activitySelected(ActivitiesStruct value) {
    _activitySelected = value;
    prefs.setString('ff_activitySelected', value.serialize());
  }

  void updateActivitySelectedStruct(Function(ActivitiesStruct) updateFn) {
    updateFn(_activitySelected);
    prefs.setString('ff_activitySelected', _activitySelected.serialize());
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

  ActivitiesStatusStruct _activityStatusSelected = ActivitiesStatusStruct();
  ActivitiesStatusStruct get activityStatusSelected => _activityStatusSelected;
  set activityStatusSelected(ActivitiesStatusStruct value) {
    _activityStatusSelected = value;
  }

  void updateActivityStatusSelectedStruct(
      Function(ActivitiesStatusStruct) updateFn) {
    updateFn(_activityStatusSelected);
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

  dynamic _activitySelectedCopy;
  dynamic get activitySelectedCopy => _activitySelectedCopy;
  set activitySelectedCopy(dynamic value) {
    _activitySelectedCopy = value;
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
