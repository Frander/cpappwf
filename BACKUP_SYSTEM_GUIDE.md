# Sistema de Copias de Seguridad (Backup)

## Descripción General

El sistema de backup te permite crear copias de seguridad completas de:

1. **Base de Datos SQLite** - Todos tus datos de empresas, usuarios, zonas, actividades, productos, visitas, etc.
2. **App State Persistente** - Configuraciones personales, preferencias, estados guardados.

## Estructura de Carpetas

```
Documents/
└── Backups/
    ├── Backup_2026_02_11__19_04/
    │   ├── clickpalm_database.db      (Base de datos SQLite)
    │   ├── backup_config.json          (Configuraciones App State)
    │   └── backup_info.txt             (Información del backup)
    ├── Backup_2026_02_10__14_30/
    │   ├── clickpalm_database.db
    │   ├── backup_config.json
    │   └── backup_info.txt
    └── ...
```

## Funcionalidades Principales

### 1. Crear Backup

**Ubicación:** Configuración > Copias de Seguridad > Crear Nueva Copia de Seguridad

**¿Qué se guarda?**

- Base de datos completa con todas las tablas
- App State persistentes incluyendo:
  - Datos de usuario, empresa, dispositivo
  - Configuraciones de rutas
  - Lista de noticias
  - Visitas agregadas
  - Ubicaciones geográficas
  - Detalles de visitas
  - Y más...

**Proceso:**
1. Presiona el botón "Crear Nueva Copia de Seguridad"
2. Se crea una carpeta con formato: `Backup_YYYY_MM_DD__HH_MM`
3. Se copian todos los archivos necesarios
4. Recibirás una notificación cuando esté completo

### 2. Restaurar Backup

**Ubicación:** Configuración > Copias de Seguridad > (Selecciona un backup) > Restaurar

**¿Qué sucede?**

1. Se realiza una validación del backup
2. Se crea un respaldo de los datos actuales (con timestamp)
3. Se restauran los datos del backup anterior
4. Se reestablecer la conexión a la base de datos
5. La app se reinicia para aplicar los cambios

**Advertencia:** Esta acción reemplaza todos los datos actuales con los del backup seleccionado.

### 3. Eliminar Backup

**Ubicación:** Configuración > Copias de Seguridad > (Selecciona un backup) > Eliminar

Elimina la carpeta completa del backup. Esta acción no se puede deshacer.

## Contenido del Backup

### Archivo: `backup_config.json`

Contiene todos los app states persistentes en formato JSON:

```json
{
  "backup_info": {
    "timestamp": "2026-02-11T19:04:30.123456",
    "formatted_date": "11/02/2026",
    "formatted_time": "19:04:30"
  },
  "boolean_states": {
    "isSync": true,
    "isCalibrateVoice": false,
    "calibrateCompass": true
  },
  "string_states": {
    "pathDatabase": "/path/to/database",
    "androidID": "device_id_123",
    "sp3NavFile": "file_path",
    "pathPmtiles": "pmtiles_path"
  },
  "numeric_states": {
    "lastLineInstall": 100,
    "lastPalmInstall": 50,
    ...
  },
  "headquarters_list": [
    { "id_headquarter": 1, "name_headquarter": "Sede Principal", ... },
    { "id_headquarter": 2, "name_headquarter": "Sede Sucursal", ... }
  ],
  "products_list": [
    { "id_product": 1, "name_product": "Producto A", ... }
  ],
  ...
}
```

### Archivo: `backup_info.txt`

Información legible sobre el backup:

```
╔════════════════════════════════════════════════════════════════╗
║                   INFORMACIÓN DEL BACKUP                      ║
╚════════════════════════════════════════════════════════════════╝

FECHA Y HORA
───────────────────────────────────────────────────────────────
Fecha: 11/02/2026
Hora:  19:04:30
ISO:   2026-02-11T19:04:30.123456

DISPOSITIVO
───────────────────────────────────────────────────────────────
Nombre: Mi Dispositivo
IMEI1: 359846082850493
Model: Samsung Galaxy A12
Estado: Activo

USUARIO
───────────────────────────────────────────────────────────────
Nombre: Juan Diego Duque
Email: juan@example.com
Operador ID: OP-001

EMPRESA
───────────────────────────────────────────────────────────────
Nombre: ClickPalm S.A.
Razón Social: ClickPalm Servicios
NIT: 123456789

CONTENIDO DEL BACKUP
───────────────────────────────────────────────────────────────
✓ Base de datos SQLite (clickpalm_database.db)
✓ Archivo de configuraciones (backup_config.json)
✓ Archivo de información (backup_info.txt)
```

### Archivo: `clickpalm_database.db`

La base de datos SQLite completa con todas las tablas:

- Companies (Empresas)
- Zones (Zonas)
- Users (Usuarios)
- Devices (Dispositivos)
- Activities (Actividades)
- Products (Productos)
- Visits (Visitas)
- Visit_details (Detalles de Visitas)
- Location_tracking (Seguimiento de ubicaciones)
- Y más...

## Gestión de Backups

### Recomendaciones

1. **Realiza backups regularmente** - Se recomienda hacer backup semanal o antes de cambios importantes
2. **Guarda copias externas** - Exporta backups a:
   - Unidad USB
   - Servicio en la nube (Google Drive, OneDrive, etc.)
   - Computadora personal
3. **Etiqueta tus backups** - Guarda una copia con el nombre del proyecto o fecha importante
4. **Prueba restauraciones** - Ocasionalmente, prueba restaurar un backup en un dispositivo de prueba

### Límites de Almacenamiento

- Cada backup ocupa aproximadamente **5-50 MB** (depende de la cantidad de datos)
- Se pueden almacenar múltiples backups
- Se recomienda mantener máximo 10-15 backups recientes

### Recuperación de Errores

Si algo falla durante la creación o restauración:

1. **Backup fallido:**
   - Intenta nuevamente
   - Verifica espacio disponible
   - Revisa permisos de almacenamiento

2. **Restauración fallida:**
   - Se crea un respaldo automático de los datos actuales
   - Busca en la carpeta del backup anterior
   - Contacta soporte si persiste el error

## Elementos Persistentes Guardados

### Estados Booleanos
- `isSync` - Estado de sincronización
- `isCalibrateVoice` - Calibración de voz completada
- `calibrateCompass` - Calibración de brújula completada

### Estados de Texto
- `pathDatabase` - Ruta de la base de datos
- `androidID` - Identificador del dispositivo Android
- `sp3NavFile` - Archivo de navegación SP3
- `pathPmtiles` - Ruta del archivo PMTiles

### Configuración de Rutas
- Línea de inicio/final
- Puntos de ruta
- Patrón de ruta
- Margen de error

### Estructuras de Datos (Structs)
- Usuario seleccionado
- Empresa predeterminada
- Dispositivo predeterminado
- Actividad seleccionada/predeterminada
- Sede seleccionada

### Listas de Objetos
- Lista de sedes
- Lista de productos
- Lista de usuarios
- Lista de zonas
- Lista de noticias
- Visitas agregadas
- Ubicaciones geográficas
- Detalles de visitas
- Estados de actividad

## Sincronización con Backend

Los backups son **almacenamiento local**. Para sincronizar con un servidor:

1. Realiza un backup local
2. Usa la función de sincronización de la app
3. Los datos se enviarán al servidor
4. El servidor mantiene su propio historial

## Soporte y Troubleshooting

### Problema: "Permisos de almacenamiento insuficientes"
**Solución:** Ve a Configuración > Aplicaciones > ClickPalm APP > Permisos > Almacenamiento > Permitir

### Problema: "Carpeta de backup no encontrada"
**Solución:** Verifica que la carpeta Documents existe y está accesible

### Problema: "El backup se corrompe"
**Solución:** 
1. No elimines archivos mientras se está creando el backup
2. Asegúrate de tener suficiente espacio libre
3. Intenta nuevamente en un momento diferente

### Problema: "La restauración no funciona"
**Solución:**
1. Verifica que el backup sea válido (debe tener los 3 archivos)
2. Cierra la app completamente antes de restaurar
3. Reinicia el dispositivo e intenta nuevamente

## API de Programador

Si eres desarrollador y deseas integrar backups en tu código:

```dart
// Crear backup
final result = await createBackup();
if (result['success']) {
  print('Backup creado en: ${result['backupPath']}');
}

// Listar backups disponibles
final backups = await listAvailableBackups();
for (final backup in backups) {
  print('${backup['name']}: Válido = ${backup['valid']}');
}

// Restaurar backup
final result = await restoreBackup(backupPath);
if (result['success']) {
  print('Backup restaurado');
}

// Eliminar backup
final result = await deleteBackup(backupPath);
if (result['success']) {
  print('Backup eliminado');
}
```

## Archivo de Ubicación

- **Acciones:** `/lib/custom_code/actions/create_backup.dart`, `restore_backup.dart`
- **Widget:** `/lib/custom_code/widgets/backup_management_widget.dart`
- **Backups:** `/Documents/Backups/`

---

**Última actualización:** 11 de febrero de 2026
**Versión:** 1.0
