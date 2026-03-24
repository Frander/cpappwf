import 'package:shared_preferences/shared_preferences.dart';

// Prefijo para las claves en SharedPreferences
const String _kHqSyncKeyPrefix = 'hq_last_sync_';

/// Guarda la fecha/hora actual como la última sincronización del lote indicado.
Future<void> saveHqSyncDate(int headquarterId) async {
  if (headquarterId <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    '$_kHqSyncKeyPrefix$headquarterId',
    DateTime.now().toIso8601String(),
  );
}

/// Retorna la última fecha de sincronización del lote, o null si nunca se sincronizó.
Future<DateTime?> getHqSyncDate(int headquarterId) async {
  if (headquarterId <= 0) return null;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_kHqSyncKeyPrefix$headquarterId');
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

/// Formatea una fecha de sincronización en texto legible.
/// Ejemplos: "Hoy 14:30", "Hace 2 días", "Hace 1 mes", "Nunca sincronizado"
String formatHqSyncDate(DateTime? date) {
  if (date == null) return 'Nunca sincronizado';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Hace un momento';
  if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
  if (diff.inDays == 0) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return 'Hoy $h:$m';
  }
  if (diff.inDays == 1) return 'Ayer';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
  if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem';
  final months = (diff.inDays / 30).floor();
  if (diff.inDays < 365) return 'Hace $months mes${months > 1 ? 'es' : ''}';
  return 'Hace más de un año';
}
