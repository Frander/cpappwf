// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// Carga los datos base desde SQLite al AppState sin llamadas a internet.
/// Se usa en el flujo de inicio de sesión cuando lastSyncBase != null
/// (datos base ya sincronizados previamente).
///
/// Carga:
///   - headquartersList  → lista de lotes disponibles
///   - activitiesJSON    → actividades con pasos y estados (para formularios)
///   - usersList         → operadores de la empresa
///
/// Retorna true si la carga fue exitosa.
Future<bool> loadAppStateFromSqlite(BuildContext context) async {
  try {
    debugPrint('');
    debugPrint('📂 [LoadSQLite] Cargando datos base desde SQLite...');

    final String dbPath = await _lsGetDatabasePath();
    final Database db  = await openDatabase(dbPath);

    // ── 1. Headquarters ────────────────────────────────────────────────────
    await _lsLoadHeadquarters(db);

    // ── 2. Users (operadores) ──────────────────────────────────────────────
    await _lsLoadUsers(db);

    // ── 3. Activities JSON (para formularios de visita) ────────────────────
    await _lsLoadActivitiesJson(db);

    await db.close();

    debugPrint('✅ [LoadSQLite] Datos cargados exitosamente:');
    debugPrint('   📍 headquarters: ${FFAppState().headquartersList.length}');
    debugPrint('   👥 users:        ${FFAppState().usersList.length}');
    debugPrint('   📋 activitiesJSON: ${FFAppState().activitiesJSON != null ? "OK" : "vacío"}');
    return true;

  } catch (e, st) {
    debugPrint('❌ [LoadSQLite] Error: $e');
    debugPrint('   Stack: $st');
    return false;
  }
}

// ============================================================================
// CARGAR HEADQUARTERS
// ============================================================================

Future<void> _lsLoadHeadquarters(Database db) async {
  try {
    final rows = await db.query(
      'Headquarters',
      columns: ['Id_headquarter', 'Id_zone', 'Created_at', 'Name_headquarter',
                 'Density_headquarter', 'Seed_time', 'State_headquarter',
                 'Area_headquarter', 'Polygon'],
      orderBy: 'Name_headquarter ASC',
    );

    final list = rows.map((r) => HeadquartersStruct(
      idHeadquarter:      r['Id_headquarter'] as int?,
      idZone:             r['Id_zone'] as int?,
      createdAt:          r['Created_at'] as String?,
      nameHeadquarter:    r['Name_headquarter'] as String?,
      densityHeadquarter: r['Density_headquarter'] != null
          ? (r['Density_headquarter'] as num).toInt() : null,
      seedTime:           r['Seed_time'] as String?,
      stateHeadquarter:   r['State_headquarter'] as String?,
      areaHeadquarter:    r['Area_headquarter'] != null
          ? (r['Area_headquarter'] as num).toDouble() : null,
      polygon:            r['Polygon'] as String?,
    )).toList();

    FFAppState().headquartersList = list;
    debugPrint('   ✅ [LoadSQLite] ${list.length} lotes cargados');
  } catch (e) {
    debugPrint('   ⚠️ [LoadSQLite] Error cargando headquarters: $e');
  }
}

// ============================================================================
// CARGAR USERS
// ============================================================================

Future<void> _lsLoadUsers(Database db) async {
  try {
    final rows = await db.query(
      'Users',
      columns: ['Id_user', 'Id_company', 'Oper_id', 'Name_user', 'Email',
                 'Created_at', 'Modified_at', 'Is_default'],
      orderBy: 'Name_user ASC',
    );

    final list = rows.map((r) => UsersStruct(
      idUser:    r['Id_user'] as int?,
      idCompany: r['Id_company'] as int?,
      operID:    r['Oper_id'] as String?,
      nameUser:  r['Name_user'] as String?,
      email:     r['Email'] as String?,
      createdAt: r['Created_at'] as String?,
    )).toList();

    FFAppState().usersList = list;
    debugPrint('   ✅ [LoadSQLite] ${list.length} usuarios cargados');
  } catch (e) {
    debugPrint('   ⚠️ [LoadSQLite] Error cargando users: $e');
  }
}

// ============================================================================
// CARGAR ACTIVITIES JSON (estructura anidada para formularios)
// ============================================================================

Future<void> _lsLoadActivitiesJson(Database db) async {
  try {
    // 1. Cargar todas las actividades
    final actRows = await db.query('Activities', orderBy: 'Id_activity ASC');
    if (actRows.isEmpty) {
      debugPrint('   ⚠️ [LoadSQLite] No hay actividades en SQLite');
      return;
    }

    // 2. Cargar todos los pasos
    final stepRows = await db.query('Activities_steps', orderBy: 'Id_activity ASC, Order_step ASC');

    // 3. Cargar todos los estados
    final statusRows = await db.query('Activities_status', orderBy: 'Id_activity ASC, Order_status ASC');

    // 4. Indexar pasos por Id_activity
    final Map<int, List<Map<String, dynamic>>> stepsByActivity = {};
    for (final s in stepRows) {
      final actId = s['Id_activity'] as int? ?? 0;
      stepsByActivity.putIfAbsent(actId, () => []).add(Map<String, dynamic>.from(s));
    }

    // 5. Indexar status por Id_activity_step_parent
    final Map<int?, List<Map<String, dynamic>>> statusByStep = {};
    // También indexar por Id_activity para reference-list
    final Map<int, List<Map<String, dynamic>>> statusByActivity = {};
    for (final st in statusRows) {
      final stepId = st['Id_activity_step_parent'] as int?;
      statusByStep.putIfAbsent(stepId, () => []).add(Map<String, dynamic>.from(st));
      final actId = st['Id_activity'] as int? ?? 0;
      statusByActivity.putIfAbsent(actId, () => []).add(Map<String, dynamic>.from(st));
    }

    // 6. Construir JSON anidado
    final List<dynamic> activitiesJson = actRows.map((a) {
      final actId = a['Id_activity'] as int? ?? 0;
      final steps = (stepsByActivity[actId] ?? []).map((s) {
        final stepId = s['Id_activity_step'] as int?;
        final typeStep = s['Type_step'] as String? ?? '';

        List<Map<String, dynamic>> normalizedStatus;
        if (typeStep == 'reference-list') {
          // Los status son de la actividad referenciada en Default_value
          final refId = int.tryParse(s['Default_value']?.toString() ?? '');
          if (refId != null) {
            // Solo status raíz de esa actividad (sin step parent y sin status parent)
            final refStatus = (statusByActivity[refId] ?? []).where((st) {
              final sp = st['Id_activity_step_parent'];
              final sap = st['Id_activity_status_parent'];
              return (sp == null || sp == 0) && (sap == null || sap == 0);
            }).toList();
            normalizedStatus = refStatus.map((st) => _lsBuildStatus(st, statusByStep)).toList();
          } else {
            normalizedStatus = [];
          }
        } else {
          final rawStatus = statusByStep[stepId] ?? [];
          normalizedStatus = rawStatus.map((st) => _lsBuildStatus(st, statusByStep)).toList();
        }

        return {
          'id_activity_step':   s['Id_activity_step'],
          'id_activity':        s['Id_activity'],
          'type_step':          typeStep,
          'order_step':         s['Order_step'],
          'default_value':      s['Default_value'],
          'unity':              s['Unity'],
          'calculation':        s['Calculation'],
          'name_step':          s['Name_step'],
          'status':             s['Status'],
          'is_required':        s['Is_required'] == 1,
          'activities_status':  normalizedStatus,
          'activity_status':    normalizedStatus,
        };
      }).toList();

      return {
        'id_activity':          a['Id_activity'],
        'id_company':           a['Id_company'],
        'id_activity_parent':   a['Id_activity_parent'],
        'name_activity':        a['Name_activity'],
        'group_activity':       a['Group_activity'],
        'unity':                a['Unity'],
        'type_activity':        a['Type_activity'],
        'type_effectivity':     a['Type_effectivity'],
        'cycle':                a['Cycle'],
        'effectivity_unitys':   a['Effectivity_unitys'],
        'effectivity_visits':   a['Effectivity_visits'],
        'module_activity':      a['Module_activity'],
        'description_activity': a['Description_activity'],
        'created_at':           a['Created_at'],
        'is_default':           a['Is_default'] == 1,
        'is_sync':              a['Is_sync'] == 1,
        'is_sync_full':         a['Is_sync_full'] == 1,
        'tracking_headquarter': a['Tracking_headquarter'] == 1,
        'read_default':         a['Read_default'],
        'activity_steps':       steps,
        'activity_status':      (statusByActivity[actId] ?? []).where((st) {
          final sp  = st['Id_activity_step_parent'];
          final sap = st['Id_activity_status_parent'];
          return (sp == null || sp == 0) && (sap == null || sap == 0);
        }).map((st) => _lsBuildStatus(st, statusByStep)).toList(),
      };
    }).toList();

    FFAppState().activitiesJSON = activitiesJson;
    debugPrint('   ✅ [LoadSQLite] ${activitiesJson.length} actividades reconstruidas desde SQLite');
  } catch (e) {
    debugPrint('   ⚠️ [LoadSQLite] Error cargando activitiesJSON: $e');
  }
}

/// Construye un Map de status con hijos anidados
Map<String, dynamic> _lsBuildStatus(
  Map<String, dynamic> st,
  Map<int?, List<Map<String, dynamic>>> statusByStep,
) {
  final statusId = st['Id_activity_status'] as int?;
  final children = (statusByStep[statusId] ?? [])
      .map((c) => _lsBuildStatus(Map<String, dynamic>.from(c), statusByStep))
      .toList();

  return {
    'id_activity_status':        st['Id_activity_status'],
    'id_activity':               st['Id_activity'],
    'id_activity_step_parent':   st['Id_activity_step_parent'],
    'id_activity_status_parent': st['Id_activity_status_parent'],
    'type_status':               st['Type_status'],
    'order_status':              st['Order_status'],
    'default_status':            st['Default_status'],
    'status_name':               st['Status_name'],
    'color':                     st['Color'],
    'peso':                      st['Peso'],
    'castigo':                   st['Castigo'],
    'boton':                     st['Boton'],
    'factor':                    st['Factor'],
    'status':                    st['Status'],
    'activities_status_childs':  children,
    'status_childs':             children,
  };
}

// ============================================================================
// RUTA DE LA BASE DE DATOS
// ============================================================================

Future<String> _lsGetDatabasePath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('[LoadSQLite] No se pudo acceder al almacenamiento externo');
  }
  final String basePath = '${externalDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}
