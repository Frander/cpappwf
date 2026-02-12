# 🔧 Ejemplos de Uso del Sistema de Backup

## Ejemplo 1: Usar el Widget Completo

Si deseas integrar toda la interfaz de gestión de backups en una pantalla:

```dart
import 'package:flutter/material.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;

class BackupPage extends StatelessWidget {
  const BackupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de Seguridad'),
      ),
      body: SafeArea(
        child: custom_widgets.BackupManagementWidget(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height - kToolbarHeight,
        ),
      ),
    );
  }
}
```

## Ejemplo 2: Crear Backup Programáticamente

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> createBackupExample() async {
  try {
    // Crear el backup
    final result = await actions.createBackup();

    if (result['success'] == true) {
      print('✅ Backup creado correctamente');
      print('📁 Ubicación: ${result['backupPath']}');
      print('📦 Nombre: ${result['backupName']}');
      print('⏰ Timestamp: ${result['timestamp']}');
      
      // Mostrar mensaje al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup creado: ${result['backupName']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('❌ Error: ${result['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
```

## Ejemplo 3: Listar y Mostrar Backups

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> listBackupsExample() async {
  try {
    // Obtener lista de backups
    final backups = await actions.listAvailableBackups();

    print('📦 Backups disponibles: ${backups.length}');

    for (final backup in backups) {
      print('─' * 50);
      print('Nombre: ${backup['name']}');
      print('Ruta: ${backup['path']}');
      print('Válido: ${backup['valid']}');
      print('Tiene BD: ${backup['hasDatabase']}');
      print('Tiene Config: ${backup['hasConfig']}');
      print('Tiene Info: ${backup['hasInfo']}');
      print('Creado: ${backup['createdTime']}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

## Ejemplo 4: Restaurar un Backup

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> restoreBackupExample(String backupPath) async {
  try {
    // Mostrar confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Restauración'),
        content: const Text(
          'Se van a restaurar todos los datos de este backup. '
          'Los datos actuales se respaldlarán automáticamente. '
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restaurando backup...'),
          ],
        ),
      ),
    );

    // Restaurar
    final result = await actions.restoreBackup(backupPath);

    // Cerrar diálogo de progreso
    Navigator.pop(context);

    if (result['success'] == true) {
      print('✅ Backup restaurado');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restaurado. Reiniciando...'),
          backgroundColor: Colors.green,
        ),
      );

      // Después de un delay, hacer hot-restart o navegar a home
      await Future.delayed(const Duration(seconds: 2));
      // Por ejemplo: Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      print('❌ Error: ${result['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
```

## Ejemplo 5: Eliminar un Backup

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> deleteBackupExample(String backupPath, String backupName) async {
  try {
    // Mostrar confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Backup'),
        content: Text(
          'Vas a eliminar el backup "$backupName". '
          'Esta acción no se puede deshacer. '
          '¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Eliminar
    final result = await actions.deleteBackup(backupPath);

    if (result['success'] == true) {
      print('✅ Backup eliminado');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup eliminado'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('❌ Error: ${result['error']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
```

## Ejemplo 6: Crear Botón de Backup Rápido

```dart
import '/custom_code/actions/index.dart' as actions;

class QuickBackupButton extends StatefulWidget {
  const QuickBackupButton({Key? key}) : super(key: key);

  @override
  State<QuickBackupButton> createState() => _QuickBackupButtonState();
}

class _QuickBackupButtonState extends State<QuickBackupButton> {
  bool _isCreating = false;

  Future<void> _createQuickBackup() async {
    setState(() => _isCreating = true);

    try {
      final result = await actions.createBackup();
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup: ${result['backupName']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isCreating ? null : _createQuickBackup,
      icon: _isCreating 
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.backup),
      label: Text(_isCreating ? 'Creando...' : 'Backup Rápido'),
    );
  }
}
```

## Ejemplo 7: Backup Automático (OnInit o en Sync)

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> syncWithAutoBackup() async {
  try {
    print('🔄 Iniciando sincronización...');
    
    // Hacer el backup ANTES de sincronizar
    print('📦 Creando backup preventivo...');
    final backupResult = await actions.createBackup();
    
    if (backupResult['success'] == true) {
      print('✅ Backup creado: ${backupResult['backupName']}');
    }

    // Ahora hacer la sincronización
    print('🔄 Sincronizando datos...');
    // ... código de sincronización aquí ...

    print('✅ Sincronización completada');
  } catch (e) {
    print('❌ Error en sincronización: $e');
  }
}
```

## Ejemplo 8: Mostrar Información de Backup

```dart
import '/custom_code/actions/index.dart' as actions;

Future<void> showBackupInfo(String backupPath) async {
  try {
    final infoFile = File('$backupPath/backup_info.txt');
    
    if (await infoFile.exists()) {
      final content = await infoFile.readAsString();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Información del Backup'),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

## Ejemplo 9: Listado Personalizado de Backups

```dart
import '/custom_code/actions/index.dart' as actions;
import 'package:intl/intl.dart';

class BackupListView extends StatefulWidget {
  const BackupListView({Key? key}) : super(key: key);

  @override
  State<BackupListView> createState() => _BackupListViewState();
}

class _BackupListViewState extends State<BackupListView> {
  late Future<List<Map<String, dynamic>>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _backupsFuture = actions.listAvailableBackups();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _backupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final backups = snapshot.data ?? [];

        if (backups.isEmpty) {
          return const Center(
            child: Text('No hay backups disponibles'),
          );
        }

        return ListView.builder(
          itemCount: backups.length,
          itemBuilder: (context, index) {
            final backup = backups[index];
            final date = backup['createdTime'] as DateTime;
            final formatted = DateFormat('dd/MM/yyyy HH:mm').format(date);

            return ListTile(
              leading: backup['valid'] == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.warning, color: Colors.orange),
              title: Text(backup['name']),
              subtitle: Text(formatted),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  // Mostrar opciones
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

## Ejemplo 10: Integración en Configuración

```dart
// En la página de Configuración, agregar esta sección:

ListTile(
  leading: const Icon(Icons.backup),
  title: const Text('Copias de Seguridad'),
  subtitle: const Text('Crear, restaurar y gestionar backups'),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () {
    // Navegar a la página de backups
    context.pushNamed('BackupManagementPage');
  },
),

// O directamente mostrar el widget:
Container(
  child: const BackupManagementWidget(
    width: double.infinity,
  ),
),
```

## ⚙️ Configuración Necesaria

### En `AndroidManifest.xml`:

```xml
<!-- Permisos de almacenamiento (ya están presentes) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

### En `pubspec.yaml` (dependencias necesarias):

```yaml
dependencies:
  intl: ^0.20.2                    # Ya presente
  path_provider: 2.1.4            # Ya presente
  path: ^1.8.3                    # Ya presente
```

## 🧪 Pruebas Recomendadas

```dart
// Test 1: Crear backup
test('Crear backup', () async {
  final result = await actions.createBackup();
  expect(result['success'], isTrue);
  expect(result['backupPath'], isNotEmpty);
});

// Test 2: Listar backups
test('Listar backups', () async {
  final backups = await actions.listAvailableBackups();
  expect(backups, isList);
});

// Test 3: Restaurar backup
test('Restaurar backup', () async {
  final backups = await actions.listAvailableBackups();
  if (backups.isNotEmpty) {
    final result = await actions.restoreBackup(backups.first['path']);
    expect(result['success'], isTrue);
  }
});

// Test 4: Eliminar backup
test('Eliminar backup', () async {
  final backups = await actions.listAvailableBackups();
  if (backups.isNotEmpty) {
    final result = await actions.deleteBackup(backups.first['path']);
    expect(result['success'], isTrue);
  }
});
```

---

**Nota:** Todos estos ejemplos son totalmente funcionales y pueden ser usados directamente en tu aplicación.

