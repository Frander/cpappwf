# 🧪 Guía de Prueba - Persistencia de ID en Android

## ⚡ Quick Start para Probar

### 1️⃣ Preparar el Entorno

```bash
# Limpia la compilación anterior
flutter clean

# Obtén dependencias más recientes
flutter pub get

# Verifica que compilas sin errores
flutter analyze
```

### 2️⃣ Instalar App en Dispositivo/Emulador

```bash
# Conecta tu dispositivo o inicia un emulador
# Verifica adb:
adb devices

# Construye instala la app en modo debug
flutter run -v
```

### 3️⃣ Monitorear Logs

En otra terminal:

```bash
# Ver logs en tiempo real
flutter logs

# O con más detalle
adb logcat -s flutter
```

## ✅ Casos de Prueba

### Prueba 1: Android 13+ (Con permisos granulares)

**Dispositivo**: Emulador Pixel 5 / Android 13+

**Pasos**:
1. Ejecuta `flutter run`
2. Cuando se solicite permiso → **Acepta**
3. Monitorea los logs

**Resultado esperado**:
```
📱 Ejecutando en Android API 33
✔️ Ubicación accesible: Documents
✔️ Ubicación accesible: AppData
✅ ID guardado en Documents: 5052547228
📊 Resultado: 1 exitosos, 0 fallidos
✅ Guardado completado exitosamente
```

### Prueba 2: Android 11-12 (Scoped Storage Completo)

**Dispositivo**: Emulador Pixel 4a / Android 12

**Pasos**:
1. Ejecuta `flutter run`
2. Cuando se solicite permiso → **Acepta**
3. Revisa logs

**Resultado esperado**:
```
📱 Ejecutando en Android API 31
✔️ Ubicación accesible: Documents
✔️ Ubicación accesible: Downloads
✔️ Ubicación accesible: AppData
✅ ID guardado en Documents: 5052547228
📊 Resultado: 3 exitosos, 0 fallidos
```

### Prueba 3: Android 10 (Legacy + Scoped Mixto)

**Dispositivo**: Emulador Pixel 3 / Android 10

**Pasos**:
1. Ejecuta `flutter run`
2. Acepta permisos
3. Revisa logs

**Resultado esperado**:
```
📱 Ejecutando en Android API 29
✔️ Ubicación accesible: Documents
✔️ Ubicación accesible: Downloads
✔️ Ubicación accesible: AppData
✅ ID guardado en Documents: 5052547228
```

### Prueba 4: Con Permisos Denegados

**Dispositivo**: Cualquiera

**Pasos**:
1. Ejecuta la app
2. Cuando solicite permiso → **Rechaza**
3. Intenta guardar de nuevo

**Resultado esperado**:
```
⏭️ Ubicación no accesible: Documents (Permission denied)
⏭️ Ubicación no accesible: Downloads (Permission denied)
✔️ Ubicación accesible: AppData
✅ ID guardado en AppData: 5052547228
📊 Resultado: 1 exitosos, 2 fallidos
✅ Guardado completado exitosamente (fallback funcionó)
```

### Prueba 5: Verificar Archivo Guardado

**En tu dispositivo**:

```bash
# Conecta el dispositivo
adb shell

# Lista archivos en Documents
ls -la /storage/emulated/0/Documents/

# Verifica contenido del archivo
cat /storage/emulated/0/Documents/persistent_id.txt

# O en AppData
ls -la /data/data/com.clickpalm.clickpalmapp/

# Salir
exit
```

## 🔍 Logs para Debuggear

### Buscar en los Logs

```bash
# Solo ver logs de Flutter
flutter logs --filter "flutter"

# Ver logs de persistencia
flutter logs --filter "DocumentFile|Permission|Storage|persistent"

# Ver todo con búsqueda regex
adb logcat -s "*persistent*"
```

### Simbolos en Logs

- `📱` = Información de dispositivo
- `✔️` = Accesibilidad verificada
- `⏭️` = Ubicación saltada (no accesible)
- `✅` = Guardado exitoso
- `❌` = Error durante guardado
- `📊` = Resumen estadístico

## 🚀 Prueba de Rendimiento

### Tiempo de Ejecución

Medir tiempo desde inicio hasta fin:

```bash
# En los logs, busca:
# START: [timestamp guardado arriba]
# END: [timestamp resultado final]

# Tiempo esperado: 100-500ms en la mayoría de dispositivos
```

### Uso de Memoria

```bash
# Monitorear memoria durante ejecución
adb shell dumpsys meminfo com.clickpalm.clickpalmapp

# Verificar antes y después
```

## 🐛 Troubleshooting

### Problema: "Permission denied (errno 13)"

**Causa**: Permisos no solicitados o denegados

**Solución**:
1. Abre Settings → Aplicaciones → ClickPalm
2. Busca "Permiso"
3. Habilita acceso a almacenamiento
4. Reinicia la app

### Problema: "Documents directory not found"

**Causa**: El directorio no existe o no es accesible

**Solución**:
1. El código lo crea automáticamente
2. Si sigue fallando, revisa permisos

### Problema: "No space left on device"

**Causa**: Almacenamiento lleno

**Solución**:
1. Libera espacio en el dispositivo
2. Limpia cache de la app: `adb shell pm trim-caches 100000000`

### Problema: Logs no aparecen

**Solución**:
```bash
# Reinicia ADB
adb kill-server
adb start-server

# O revisa que el device está conectado
adb devices -l
```

## 📊 Matriz de Compatibilidad a Probar

```
┌─────────────┬─────────┬──────────────┬──────────────┐
│ Android Ver │ Device  │ Esperado     │ Verificado   │
├─────────────┼─────────┼──────────────┼──────────────┤
│ 14          │ Pixel 8 │ Documents ✓  │ [ ] Testar   │
│ 13          │ Pixel 7 │ Documents ✓  │ [ ] Testar   │
│ 12          │ Pixel 6 │ Documents ✓  │ [ ] Testar   │
│ 11          │ Pixel 4a│ Documents ✓  │ [ ] Testar   │
│ 10          │ Pixel 3 │ Documents ✓  │ [ ] Testar   │
│ 9           │ Nougat  │ AppData ✓    │ [ ] Testar   │
└─────────────┴─────────┴──────────────┴──────────────┘
```

## 🎯 Puntos de Control

Antes de deploar la versión final:

- [ ] ✅ Prueba en Android 13+ (múltiples dispositivos)
- [ ] ✅ Prueba en Android 11-12 (múltiples dispositivos)
- [ ] ✅ Prueba en Android 10 (al menos uno)
- [ ] ✅ Prueba con permisos rechazados
- [ ] ✅ Verifica que el archivo se crea en las ubicaciones esperadas
- [ ] ✅ Revisa logs para errores no esperados
- [ ] ✅ Prueba reinstalación de app (¿se preserva?)
- [ ] ✅ Prueba limpieza de datos (¿se regenera?)

## 📱 Emuladores Recomendados para Pruebas

```
# Android 14 (API 34)
emulator -avd Pixel_8_API_34 -no-boot-anim

# Android 13 (API 33)
emulator -avd Pixel_7_API_33 -no-boot-anim

# Android 12 (API 32)
emulator -avd Pixel_6_API_32 -no-boot-anim

# Android 11 (API 30)
emulator -avd Pixel_5_API_30 -no-boot-anim

# Android 10 (API 29)
emulator -avd Pixel_4_API_29 -no-boot-anim
```

## 📝 Template de Reporte

Al completar pruebas, reporta:

```
PRUEBA: [Descripción]
─────────────────────────────
Dispositivo: [Modelo]
Android: [Versión]
Conectividad: [WiFi/Datos/USB]

Resultado: ✅ EXITOSO / ❌ FALLIDO

Logs:
[Pega logs relevantes aquí]

Notas:
[Observaciones adicionales]
```

## 🔗 Referencias Útiles

- Flutter Logs: `flutter logs --help`
- ADB Commands: `adb help`
- Android Storage: https://developer.android.com/about/versions/12/behavior-changes-12
- Scoped Storage: https://developer.android.com/about/versions/11/privacy/storage

---

**Última actualización**: 12/02/2026
**Versión del código**: save_persistent_id.dart v2.0
