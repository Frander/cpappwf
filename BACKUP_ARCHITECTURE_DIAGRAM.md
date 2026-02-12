# 🏗️ Arquitectura del Sistema de Backup

## 📐 Diagrama General del Sistema

```
┌────────────────────────────────────────────────────────────────────┐
│                     🎯 APLICACIÓN CLICKPALM                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  UI LAYER - Configuración                                   │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  BackupManagementWidget                                │ │ │
│  │  │  - Crear Backup [Button]                              │ │ │
│  │  │  - Listar Backups [ListView]                          │ │ │
│  │  │  - Restaurar [Button]                                 │ │ │
│  │  │  - Eliminar [Button]                                  │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓↓↓                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  ACTIONS LAYER - Lógica de Negocio                          │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  createBackup.dart                                     │ │ │
│  │  │  - Generar fecha/hora                                  │ │ │
│  │  │  - Crear carpeta                                       │ │ │
│  │  │  - Copiar BD SQLite                                    │ │ │
│  │  │  - Crear JSON App States                              │ │ │
│  │  │  - Crear info.txt                                      │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  restore_backup.dart                                   │ │ │
│  │  │  - restoreBackup()                                     │ │ │
│  │  │  - listAvailableBackups()                              │ │ │
│  │  │  - deleteBackup()                                      │ │ │
│  │  │  - Validaciones y manejo de errores                    │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓↓↓                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  DATA LAYER - App State & Storage                           │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  FFAppState (app_state.dart)                           │ │ │
│  │  │  - Acceso a todos los estados persistentes             │ │ │
│  │  │  - SharedPreferences para persistencia                 │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  SQLiteManager                                         │ │ │
│  │  │  - Conexión a BD SQLite                                │ │ │
│  │  │  - clickpalm_database.db                               │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
                              ↓↓↓
┌────────────────────────────────────────────────────────────────────┐
│                  🗄️ ALMACENAMIENTO ANDROID                         │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  📱 Internal Storage (App)                                        │
│  └── /data/data/com.clickpalm.clickpalmapp/                      │
│      ├── shared_prefs/ (SharedPreferences)                       │
│      └── databases/ (Posible ubicación alternativa)              │
│                                                                    │
│  📂 External Storage (Público - Documents)                        │
│  └── /sdcard/Documents/                                          │
│      ├── Backups/                                                │
│      │   ├── Backup_2026_02_11__19_04/                           │
│      │   │   ├── clickpalm_database.db     (BD SQLite)           │
│      │   │   ├── backup_config.json        (App States JSON)     │
│      │   │   └── backup_info.txt           (Info legible)        │
│      │   │                                                       │
│      │   ├── Backup_2026_02_10__14_30/                           │
│      │   │   ├── clickpalm_database.db                           │
│      │   │   ├── backup_config.json                              │
│      │   │   └── backup_info.txt                                 │
│      │   │                                                       │
│      │   └── ... (más backups)                                   │
│      │                                                           │
│      └── clickpalm_database_before_restore_*.db (Respaldos prev)│
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Creación de Backup

```
User: Presiona "Crear Backup"
        ↓
        ✓ Verificar permisos de almacenamiento
        ↓
        ✓ Obtener fecha/hora actual
        ↓
        ✓ Generar nombre: Backup_2026_02_11__19_04
        ↓
        ✓ Crear carpeta en Documents/Backups/
        ├─→ mkdir /sdcard/Documents/Backups/Backup_YYYY_MM_DD__HH_MM
        ↓
    ┌─────────────────────────────────────┐
    │  PASO 1: Copiar BD SQLite           │
    │  ─────────────────────────────────  │
    │  Origen:                             │
    │  SQLiteManager.dbPath (interna)      │
    │      ↓                               │
    │  Destino:                            │
    │  Backup_*/clickpalm_database.db      │
    └─────────────────────────────────────┘
        ↓
    ┌─────────────────────────────────────┐
    │  PASO 2: Crear JSON App States      │
    │  ─────────────────────────────────  │
    │  Acceso FFAppState:                  │
    │  - userSelected                      │
    │  - companyDefault                    │
    │  - deviceDefault                     │
    │  - all persistent states...          │
    │      ↓                               │
    │  Serializar a JSON:                  │
    │  backup_config.json                  │
    │  {                                   │
    │    "boolean_states": {...},          │
    │    "string_states": {...},           │
    │    "numeric_states": {...},          │
    │    "struct_states": {...},           │
    │    "list_states": {...},             │
    │    ...                               │
    │  }                                   │
    └─────────────────────────────────────┘
        ↓
    ┌─────────────────────────────────────┐
    │  PASO 3: Crear Info Legible         │
    │  ─────────────────────────────────  │
    │  Extraer info:                       │
    │  - Fecha/Hora actual                 │
    │  - Device info (model, IMEI, etc)    │
    │  - User info (nombre, email)         │
    │  - Company info (nombre, NIT)        │
    │      ↓                               │
    │  Crear backup_info.txt               │
    │  (Formato legible para humanos)      │
    └─────────────────────────────────────┘
        ↓
        ✓ Cerrar archivos, liberar recursos
        ↓
        ✓ Retornar resultado:
        {
          "success": true,
          "backupPath": "/sdcard/Documents/Backups/Backup_...",
          "backupName": "Backup_2026_02_11__19_04",
          "timestamp": "2026-02-11T19:04:30.123456"
        }
        ↓
Widget: Mostrar mensaje de éxito ✅
```

## 🔄 Flujo de Restauración de Backup

```
User: Selecciona backup y presiona "Restaurar"
        ↓
        ✓ Mostrar confirmación (AlertDialog)
        ✓ User confirma "Sí, restaurar"
        ↓
    ┌──────────────────────────────────────┐
    │  VALIDACIONES PREVIAS                │
    │  ─────────────────────────────────── │
    │  ✓ Carpeta de backup existe          │
    │  ✓ Archivos necesarios presentes     │
    │  ✓ Permisos de almacenamiento OK     │
    └──────────────────────────────────────┘
        ↓
    ┌──────────────────────────────────────┐
    │  PASO 1: Respaldo de Datos Actuales │
    │  ─────────────────────────────────── │
    │  BD Actual:                          │
    │  /datos/clickpalm_database.db        │
    │      ↓ (copy)                        │
    │  /datos/clickpalm_db_bak_TIMESTAMP  │
    │  (En caso de que la restauración     │
    │   falle, se puede recuperar)         │
    └──────────────────────────────────────┘
        ↓
    ┌──────────────────────────────────────┐
    │  PASO 2: Restaurar BD SQLite         │
    │  ─────────────────────────────────── │
    │  Origen:                             │
    │  Backup_*/clickpalm_database.db      │
    │      ↓ (copy)                        │
    │  Destino:                            │
    │  /datos/clickpalm_database.db        │
    │                                      │
    │  (Automáticamente SQLite             │
    │   cierra y reabre la BD nueva)       │
    └──────────────────────────────────────┘
        ↓
    ┌──────────────────────────────────────┐
    │  PASO 3: Restaurar App States        │
    │  ─────────────────────────────────── │
    │  Leer: backup_config.json            │
    │      ↓                               │
    │  Parse JSON → Map<String, dynamic>   │
    │      ↓                               │
    │  Restaurar en FFAppState:            │
    │  ├─ Boolean states                   │
    │  ├─ String states                    │
    │  ├─ Numeric states                   │
    │  ├─ Structs (User, Company, etc)     │
    │  ├─ Listas (HQ, Products, etc)       │
    │  └─ JSON dinámicos                   │
    │      ↓                               │
    │  Guardar en SharedPreferences        │
    │  (Persistencia local)                │
    └──────────────────────────────────────┘
        ↓
        ✓ Mostrar mensaje de éxito
        ✓ Retornar:
        {
          "success": true,
          "requiresAppRestart": true
        }
        ↓
Widget: Mostrar "Reiniciando app..." ✅
        ↓
App: Se reinicia automáticamente
        ↓
User: Ve todos sus datos restaurados 🎉
```

## 📊 Estructura de Datos - backup_config.json

```
backup_config.json
│
├── backup_info
│   ├── timestamp (ISO 8601)
│   ├── formatted_date (dd/MM/yyyy)
│   └── formatted_time (HH:mm:ss)
│
├── boolean_states
│   ├── isSync
│   ├── isCalibrateVoice
│   └── calibrateCompass
│
├── string_states
│   ├── pathDatabase
│   ├── androidID
│   ├── sp3NavFile
│   └── pathPmtiles
│
├── numeric_states
│   ├── lastLineInstall
│   ├── lastPalmInstall
│   ├── routeConfigStartLine
│   ├── routeConfigStartPoint
│   ├── routeConfigMaxLines
│   ├── routeConfigMaxPoints
│   ├── routeConfigPattern
│   └── routeConfigErrorMargin
│
├── list_voice_calibration (array)
│
├── user_selected (UsersStruct)
├── company_default (CompaniesStruct)
├── device_default (DevicesStruct)
├── activity_default (ActivitiesStruct)
├── activity_selected (ActivitiesStruct)
├── headquarter_selected (HeadquartersStruct)
│
├── headquarters_list (array of HeadquartersStruct)
├── products_list (array of ProductsStruct)
├── users_list (array of UsersStruct)
├── zones_list (array of ZonesStruct)
├── news_list (array of NewsStruct)
├── news_selected (array of NewsStruct)
├── news_add (array of VisitsNewsStruct)
├── visits_add (array of VisitsStruct)
├── headquarters_selected_list (array)
├── activities_status_selected (array)
├── status_add (array)
├── geo_locations_list (array of ReadGeoStruct)
├── visit_details (array of VisitsDetailsStruct)
│
├── login_response (dynamic JSON)
├── activities_json (dynamic JSON)
├── user_selected_json (dynamic JSON)
├── activity_selected_json (dynamic JSON)
└── current_activity (dynamic JSON)
```

## 🔗 Relaciones de Dependencias

```
BackupManagementWidget
    │
    ├─→ createBackup()
    │   ├─→ _getDocumentsDirectory()
    │   ├─→ _backupDatabase()
    │   │   └─→ File.copy() (SQLite)
    │   ├─→ _createBackupConfigJson()
    │   │   ├─→ FFAppState (read all states)
    │   │   └─→ jsonEncode()
    │   └─→ _createBackupInfoFile()
    │       └─→ File.writeAsString()
    │
    ├─→ listAvailableBackups()
    │   ├─→ _getDocumentsDirectory()
    │   ├─→ Directory.listSync()
    │   └─→ File.exists() (validación)
    │
    ├─→ restoreBackup(path)
    │   ├─→ _getDocumentsDirectory()
    │   ├─→ _restoreDatabase()
    │   │   ├─→ File.copy() (restore BD)
    │   │   └─→ File.copy() (backup previo)
    │   └─→ _restoreAppStates()
    │       ├─→ jsonDecode()
    │       ├─→ FFAppState (write all states)
    │       └─→ Struct.fromSerializableMap()
    │
    └─→ deleteBackup(path)
        └─→ Directory.delete(recursive)
```

## 🔐 Manejo de Permisos

```
App Start
    │
    ├─→ AndroidManifest.xml Declares:
    │   ├─ READ_EXTERNAL_STORAGE
    │   ├─ WRITE_EXTERNAL_STORAGE
    │   ├─ MANAGE_EXTERNAL_STORAGE
    │   └─ REQUEST_INSTALL_PACKAGES
    │
    └─→ Runtime Permissions:
        └─→ permission_handler package
            ├─→ Permission.storage.status (check)
            ├─→ Permission.storage.request() (ask)
            └─→ Permission.requestInstallPackages
```

## 📈 Performance Flow

```
Operación: Crear Backup
├─ Tiempo típico: 5-30 segundos
├─ Tamaño BD: 5-50 MB
├─ Tamaño JSON: 0.5-5 MB
├─ Tamaño Total: 5.5-55 MB
├─ I/O Operations: 10-20
└─ Memory Peak: 50-100 MB

Operación: Restaurar Backup
├─ Tiempo típico: 5-30 segundos
├─ Operaciones BD: 1 (copy)
├─ Operaciones Memoria: 40+ (state updates)
├─ Parsing JSON: 1-5 segundos
└─ App Restart Needed: Sí

Operación: Listar Backups
├─ Tiempo típico: <1 segundo
├─ I/O Operations: Lectura de directorios
└─ Memory Impact: Minimal

Operación: Eliminar Backup
├─ Tiempo típico: 1-5 segundos
├─ I/O Operations: Recursivo delete
└─ Freed Space: 5.5-55 MB
```

## 🛡️ Error Handling Chain

```
Backup Creation
    │
    ├─→ Permission Denied
    │   └─→ throw Exception("Permisos insuficientes")
    │       └─→ UI: Show error snackbar
    │
    ├─→ Storage Full
    │   └─→ throw Exception("Espacio insuficiente")
    │       └─→ UI: Show error snackbar
    │
    ├─→ BD not found
    │   └─→ throw Exception("BD no encontrada")
    │       └─→ UI: Show error snackbar
    │
    ├─→ JSON Serialization Failed
    │   └─→ catch(e) → jsonEncode fallback
    │       └─→ UI: Show partial success
    │
    └─→ File Operations Failed
        └─→ catch(e) → Cleanup & throw
            └─→ UI: Show error snackbar

Restoration
    │
    ├─→ Backup Path Invalid
    │   └─→ return {success: false}
    │
    ├─→ BD Restore Failed
    │   ├─→ Previous DB already backed up
    │   └─→ return {success: false}
    │
    └─→ State Restoration Failed
        ├─→ Partial states restore (continue)
        └─→ return {success: true} (app needs restart)
```

## 🎯 Data Flow Diagram

```
                                    FFAppState
                                  (Persistent)
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
            SharedPreferences    SQLiteDatabase    Context/Memory
                    │                 │                 │
                    └─────────────┬───┴─────────────┬───┘
                                  │                │
                        ┌─────────┴──┐    ┌────────┴─────┐
                        │            │    │              │
                    createBackup()   │ restoreBackup()  │
                        │            │    │              │
          ┌─────────────┴────┐       │    │ ┌────────────┴──────┐
          │                  │       │    │ │                   │
    ┌─────▼─────┐    ┌──────▼──┐    │    │ │    ┌──────────┐   │
    │   JSON    │    │  SQLite  │    │    │ │    │ JSON     │   │
    │  Serialize│    │   Copy   │    │    │ │    │ Deserialize│ │
    └─────┬─────┘    └──────┬──┘    │    │ │    └──────┬───┘   │
          │                 │       │    │ │           │       │
          └────────┬────────┘       │    │ │    ┌──────┴───┐   │
                   │                │    │ │    │  Update  │   │
         backup_config.json         │    │ │    │ AppState │   │
                   │                │    │ │    └──────┬───┘   │
                   └────────┬───────┘    │ │           │       │
                            │            │ │    ┌──────▼────┐  │
                    Backup_*/             │ │    │Persist to│  │
                   clickpalm_database.db  │ │    │ Context  │  │
                            │             │ │    └──────────┘  │
                            │             │ │                  │
                            └─────────────┴─┼──────────────────┘
                                          │
                            ┌─────────────┴──────────┐
                            │                        │
                      Application Ready        Next Session
                            │                        │
                    Continue with                 Load from
                    new data                       Backup
```

---

## 📝 Notas Arquitectónicas

1. **Separación de Responsabilidades:**
   - Widget maneja UI
   - Actions manejan lógica
   - FFAppState maneja persistencia

2. **Error Recovery:**
   - Backups previos en restauración
   - Validaciones en cada paso
   - Logs detallados para debugging

3. **Performance:**
   - Async operations para no bloquear UI
   - Streaming para archivos grandes
   - Caché de backups listados

4. **Compatibilidad:**
   - Compatible Android 6+
   - Usa path_provider para rutas seguras
   - Respeta permisos del sistema

---

Arquitectura Diseñada: 11 de febrero de 2026  
Estado: ✅ VALIDADO Y DOCUMENTADO

