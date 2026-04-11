# PLAN 2 — ADB Port Forwarding WebSocket para `tag-transfer-adb`

### Contexto
Se necesita una nueva modalidad de transferencia NFC que funcione en Windows sin hardware NFC. El móvil actúa como lector NFC via USB (ADB). El desktop abre un servidor WebSocket en puerto 8080 **únicamente** cuando el formulario renderiza un campo de tipo `tag-transfer-adb`. El móvil lee el tag NFC y empuja los datos en tiempo real al desktop por WebSocket.

### Arquitectura

```
[Formulario Desktop renderiza tag-transfer-adb]
        ↓
[AdbNfcBridgeService.start() → WebSocket server :8080]
        ↓ (USB ADB: adb forward tcp:8080 tcp:8080)
[App móvil detecta conexión → muestra UI "Leer NFC"]
        ↓
[Técnico acerca tag NFC al móvil]
        ↓
[Móvil lee NFC → envía JSON por WebSocket]
        ↓
[Desktop recibe → actualiza estado del campo en tiempo real]
        ↓
[Campo marcado como completado con los datos del tag]

[Al salir del campo / cerrar formulario → WebSocket server se cierra]
```

---

### Archivos nuevos a crear

#### A. `lib/custom_code/actions/adb_nfc_bridge_service.dart`
Servicio singleton que gestiona el WebSocket server:

```dart
// Responsabilidades:
// - start(): abre HttpServer + WebSocketTransformer en puerto 8080
// - stop(): cierra server y todas las conexiones
// - onTagReceived: Stream<Map<String,dynamic>> para escuchar datos NFC
// - isRunning: bool
// - broadcastStatus(): envía estado al cliente conectado

class AdbNfcBridgeService {
  static final instance = AdbNfcBridgeService._();
  HttpServer? _server;
  WebSocket? _client;
  final _controller = StreamController<Map<String,dynamic>>.broadcast();
  
  Stream<Map<String,dynamic>> get onTagReceived => _controller.stream;
  bool get isRunning => _server != null;
  
  Future<void> start() async { ... }  // puerto 8080
  Future<void> stop() async { ... }
  void _handleMessage(dynamic data) { ... }  // parsea JSON del móvil
}
```

#### B. `lib/components/tag_transfer_adb_dialog_widget.dart`
Widget dialog que muestra:
- Estado de conexión ADB (esperando / conectado / recibiendo)
- Instrucciones: "Conecta el móvil por USB y abre ClickPalm en el móvil"
- Indicador en tiempo real (StreamBuilder sobre `onTagReceived`)
- Botón cancelar

---

### Cambios en archivos existentes

#### C. `lib/visits/do_visits_form_page/do_visits_form_page_widget.dart`

**Paso C1 — Declaración de tipo (en el bloque de boolean flags ~línea 1422):**
```dart
final isTagTransferAdbType = typeStatus.toLowerCase() == 'tag-transfer-adb';
```

**Paso C2 — State maps (en los campos de estado de la clase):**
```dart
final Map<int, Map<String,dynamic>> _tagTransferAdbData = {};
final Map<int, bool> _tagTransferAdbCompleted = {};
```

**Paso C3 — Tap handler (después del if isTagTransferType ~línea 1957):**
```dart
if (isTagTransferAdbType) {
  // Solo en Windows — el tap abre el dialog ADB
  if (Platform.isWindows) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TagTransferAdbDialogWidget(
        statusId: statusId,
        onTagReceived: (data) {
          setState(() {
            _tagTransferAdbData[statusId] = data;
            _tagTransferAdbCompleted[statusId] = true;
          });
        },
      ),
    );
  }
  return;
}
```

**Paso C4 — Inline button rendering (en el bloque de botones ~línea 1489+):**
```dart
if (isTagTransferAdbType && Platform.isWindows)
  Padding(
    padding: const EdgeInsets.only(left: 8),
    child: _buildTagTransferAdbButton(
      statusId: statusId,
      statusName: statusName,
    ),
  ),
```

**Paso C5 — Summary display:**
```dart
if (isTagTransferAdbType && _tagTransferAdbData.containsKey(statusId))
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: _buildTagTransferAdbSummary(statusId: statusId),
  ),
```

**Paso C6 — Helper methods al final del archivo:**
- `_buildTagTransferAdbButton()` — ícono USB + texto "Leer via ADB", color distinto (ej. purple/indigo)
- `_buildTagTransferAdbSummary()` — mismo patrón que `_buildTagTransferSummary()` pero con label "ADB"
- `_buildTagTransferAdbCleanupButton()` — botón limpiar datos

**Nota:** Aplicar los mismos 6 pasos a `lib/visits/formulario_extractora_form_page/formulario_extractora_form_page_widget.dart` en las líneas correspondientes (1664-1683 flags, 1957+ tap handler, 3509-3550 buttons, 3570-3586 summary).

#### D. Lifecycle del WebSocket server

El servidor debe abrirse/cerrarse en sync con el formulario:
- **Abrir**: cuando `isTagTransferAdbType == true` en algún campo del formulario renderizado → en `initState`
- **Cerrar**: en `dispose()` del widget del formulario

```dart
@override
void initState() {
  super.initState();
  if (Platform.isWindows && _hasTagTransferAdbField()) {
    AdbNfcBridgeService.instance.start();
  }
}

@override
void dispose() {
  if (Platform.isWindows) {
    AdbNfcBridgeService.instance.stop();
  }
  super.dispose();
}

bool _hasTagTransferAdbField() {
  // Recorre widget.activityStatuses buscando typeStatus == 'tag-transfer-adb'
}
```

---

### Protocolo WebSocket (mensaje del móvil al desktop)

```json
{
  "type": "nfc_tag_read",
  "payload": {
    "tagContent": "...",
    "productName": "...",
    "timestamp": "..."
  }
}
```

---

### Archivos críticos de referencia para implementación

| Archivo | Para qué |
|---------|----------|
| `lib/visits/do_visits_form_page/do_visits_form_page_widget.dart` L1422 | Copiar patrón de boolean flags |
| `lib/visits/do_visits_form_page/do_visits_form_page_widget.dart` L1957 | Copiar patrón tap handler tag-transfer |
| `lib/components/nfc_transfer_write_dialog_widget.dart` | Copiar estructura del dialog NFC para el nuevo dialog ADB |
| `lib/visits/formulario_extractora_form_page/formulario_extractora_form_page_widget.dart` L1664-1683 | Mismas adiciones en extractora |
| `lib/visits/formulario_extractora_form_page/formulario_extractora_form_page_widget.dart` L7510 | Copiar patrón _buildTagTransferButton |
| `lib/visits/formulario_extractora_form_page/formulario_extractora_form_page_widget.dart` L12276 | Copiar patrón _buildTagTransferSummary |

---

### Verificación Plan 2
1. En Windows: abrir formulario con campo `tag-transfer-adb` → verificar que `AdbNfcBridgeService` levanta server en :8080
2. Conectar móvil por USB → ejecutar `adb forward tcp:8080 tcp:8080` → verificar WebSocket conecta
3. Simular envío de JSON desde móvil (wscat o Postman) → verificar que el campo del formulario se actualiza en tiempo real
4. Cerrar formulario → verificar que el server se detiene
5. Abrir formulario SIN campo `tag-transfer-adb` → verificar que el server NO se abre
6. En Android: verificar que el campo `tag-transfer-adb` no genera errores (guard `Platform.isWindows`)
