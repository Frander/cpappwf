import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:intl/intl.dart';

/// Widget para gestionar copias de seguridad (backups)
/// Incluye crear, restaurar y eliminar backups
class BackupManagementWidget extends StatefulWidget {
  const BackupManagementWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<BackupManagementWidget> createState() => _BackupManagementWidgetState();
}

class _BackupManagementWidgetState extends State<BackupManagementWidget> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _backups = [];
  String _message = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _message = 'Cargando backups...';
      _isError = false;
    });

    try {
      final backups = await actions.listAvailableBackups();
      setState(() {
        _backups = backups;
        _message = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _message = 'Error al cargar backups: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _message = 'Creando backup...';
      _isError = false;
    });

    try {
      final result = await actions.createBackup();

      if (result['success'] == true) {
        setState(() {
          _message = result['message'];
          _isError = false;
        });

        // Recargar lista después de 1 segundo
        await Future.delayed(const Duration(seconds: 1));
        await _loadBackups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: FlutterFlowTheme.of(context).success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isError = true;
          _message = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _message = 'Error creando backup: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    // Mostrar confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Restauración'),
        content: const Text(
          '¿Deseas restaurar este backup? Se reemplazan todos los datos actuales.',
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

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _message = 'Restaurando backup...';
      _isError = false;
    });

    try {
      final result = await actions.restoreBackup(backupPath);

      if (result['success'] == true) {
        setState(() {
          _message = result['message'];
          _isError = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Backup restaurado. Reiniciando app...'),
              backgroundColor: FlutterFlowTheme.of(context).success,
              duration: const Duration(seconds: 3),
            ),
          );

          // Pequeño delay antes de reiniciar
          await Future.delayed(const Duration(seconds: 2));
          // En una app real, aquí irías a hacer un hot restart
          // o simplemente navegar a la pantalla principal
        }
      } else {
        setState(() {
          _isError = true;
          _message = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _message = 'Error restaurando backup: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBackup(String backupPath, String backupName) async {
    // Mostrar confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Deseas eliminar el backup "$backupName"? Esta acción no se puede deshacer.',
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

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _message = 'Eliminando backup...';
    });

    try {
      final result = await actions.deleteBackup(backupPath);

      if (result['success'] == true) {
        setState(() {
          _message = 'Backup eliminado correctamente';
          _isError = false;
        });

        await _loadBackups();
      } else {
        setState(() {
          _isError = true;
          _message = result['error'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _message = 'Error eliminando backup: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Copias de Seguridad',
              style: FlutterFlowTheme.of(context).headlineSmall,
            ),
            const SizedBox(height: 12),

            // Descripción
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).alternate,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Haz copias de seguridad de tu base de datos y configuraciones. Los backups se guardan en la carpeta "Documents/Backups" de tu dispositivo.',
                style: FlutterFlowTheme.of(context).bodySmall,
              ),
            ),
            const SizedBox(height: 20),

            // Botón de crear backup
            _buildCreateBackupButton(),
            const SizedBox(height: 24),

            // Mensaje de estado
            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? FlutterFlowTheme.of(context).error.withValues(alpha: 0.1)
                      : FlutterFlowTheme.of(context).success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError
                        ? FlutterFlowTheme.of(context).error
                        : FlutterFlowTheme.of(context).success,
                  ),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _isError
                        ? FlutterFlowTheme.of(context).error
                        : FlutterFlowTheme.of(context).success,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Lista de backups
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  color: FlutterFlowTheme.of(context).primary,
                ),
              )
            else if (_backups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.backup_outlined,
                        size: 64,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay copias de seguridad',
                        style: FlutterFlowTheme.of(context).bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu primera copia de seguridad para proteger tus datos',
                        style: FlutterFlowTheme.of(context).bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _backups.map((backup) {
                  final isValid = backup['valid'] == true;
                  final createdTime = backup['createdTime'] as DateTime;
                  final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(createdTime);

                  return _buildBackupCard(
                    backup['name'],
                    backup['path'],
                    formattedDate,
                    isValid,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateBackupButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _createBackup,
        icon: const Icon(Icons.backup),
        label: const Text('Crear Nueva Copia de Seguridad'),
        style: ElevatedButton.styleFrom(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          disabledBackgroundColor: FlutterFlowTheme.of(context).alternate,
        ),
      ),
    );
  }

  Widget _buildBackupCard(
    String name,
    String path,
    String date,
    bool isValid,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          isValid ? Icons.check_circle : Icons.warning_amber,
          color: isValid
              ? FlutterFlowTheme.of(context).success
              : FlutterFlowTheme.of(context).warning,
        ),
        title: Text(
          name,
          style: FlutterFlowTheme.of(context).bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          date,
          style: FlutterFlowTheme.of(context).bodySmall,
        ),
        trailing: SizedBox(
          width: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isValid)
                IconButton(
                  icon: Icon(
                    Icons.restore,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                  onPressed: () => _restoreBackup(path),
                  tooltip: 'Restaurar',
                ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: FlutterFlowTheme.of(context).error,
                ),
                onPressed: () => _deleteBackup(path, name),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
