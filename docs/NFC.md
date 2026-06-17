# NFC en ClickPalm — Funcionamiento y riesgos de pérdida de información

Documentación concisa de cómo la app lee y escribe tags NFC, el formato de datos y
los puntos donde puede perderse información. Basada en `lib/custom_code/actions/`.

## 1. Stack y alcance

- Librerías: `nfc_manager: ^4.0.2` + `nfc_manager_ndef: ^1.0.1`.
- **Solo móvil** (Android en la práctica): todas las acciones empiezan con
  `if (!Platforms.isMobile) return ...`. El código usa casts específicos de Android
  (`NfcTagAndroid`, `IsoDepAndroid`, `MifareClassicAndroid`, `NdefFormatableAndroid`),
  por lo que en iOS la mayoría de rutas devuelven `null` y no operan.
- Estado del NFC: `checkNfcStatus()` valida disponibilidad antes de cada sesión y
  ofrece abrir los ajustes del sistema (`MethodChannel com.clickpalm.clickpalmapp/nfc`).

## 2. Archivos clave

| Archivo | Rol |
|---|---|
| `read_n_f_c.dart` | Lectura principal (+ enriquecimiento y borrado en sesión). |
| `write_n_f_c_tag.dart` | Escritura principal (writer y transfer, con merge y recovery). |
| `write_n_f_c_tag_direct.dart` | Escritura directa sin leer previo — **solo test de capacidad**. |
| `clear_n_f_c_tag.dart` | Borrado/format del tag a contenido mínimo `"0"`. |
| `nfc_json_helper.dart` | Formato de datos: minificado/comprimido, chunks, merge, parseo. |
| `check_nfc_status.dart` | Verificación de hardware/activación de NFC. |

## 3. Tipos de tag soportados

- **NDEF** (camino normal): se lee `cachedMessage` y se escribe un Text Record.
- **Mifare Classic 1K/4K**: lectura/escritura por bloques autenticando con clave por
  defecto `FF FF FF FF FF FF`. La escritura se **limita a 240 bytes** (sectores 0–6)
  para evitar `TagLostException` por timeout, aunque la capacidad física sea ~752 B (1K).
- **DESFire (IsoDep)**: solo si está formateado como NDEF. En tag virgen se intenta
  `NdefFormatable.format()`. La memoria libre se consulta vía APDU `GET_FREE_MEMORY`
  (`90 6E 00 00 00`); si falla se asume 8192 B optimista.

## 4. Formato de datos en el tag

Estructura canónica JSON con dos bloques:

```json
{
  "Read_info": { "Id_product", "RFID", "Name_product", "Date_created", "tag_from", "tag_to", "US" },
  "Visits":    [ { "DH", "OP", "VISITS", "RESULTS", "HE" }, ... ]
}
```

Para ahorrar espacio en el tag se codifica con prefijos (`nfcEncode`/`nfcDecode`):

- **`N1:`** — JSON minificado (claves de 1 letra) cuando el payload ≤ 200 bytes.
- **`C1:`** — `base64url(zlib(JSON minificado))` cuando supera 200 bytes.
- **Multi-chunk** — el contenido base seguido de deltas `V:{...}` separados por
  `\x1E` (Record Separator). Permite **append rápido** de una visita nueva por simple
  concatenación de strings, sin descomprimir/recompr­imir dentro de la sesión NFC.
- **Array** de varios registros (un producto por RFID de origen) en transfers.

## 5. Los tres roles de operación

El comportamiento se decide por `activity_status[].type_status`:

- **tag-writer**: el tag identifica un producto (por su RFID en la tabla `Products`).
  Se valida que el `Type_product` coincida con `TYPE_PRODUCT_DEFAULT`, se añade la
  visita nueva (delta) al contenido existente y se reescribe. Las visitas **ya están
  en SQLite**; tras escribir el tag con éxito se marcan `Status=1` (`_updateVisitsStatus`).
- **tag-reader**: lee el tag, inyecta `tag_from` (RFID físico), `tag_to=''` y `US`
  (usuario) en cada registro (`_enrichReadContent`) y lo expone en `FFAppState().nfcRead`.
- **tag-transfer**: mueve datos de un tag origen a uno destino, fusionando por RFID de
  origen. El destino **acumula** varios productos (no reemplaza). Existen dos rutas:
  - Diálogo `nfc_transfer_dialog_widget`: lee origen → lee destino → fusiona Visits →
    escribe destino. **No borra el origen.**
  - `readNFC(clearAfterRead: true)` y el callback ADB (`onTagReadCallback`): leen y
    **borran el origen en la misma sesión** tras leer / tras enviar al servidor.

## 6. Mecanismos de protección ya implementados

El código tiene defensas explícitas contra pérdida de datos:

1. **Reintentos de escritura** (`_writeNdefWithRetry`, 3 intentos) ante errores
   transitorios (`IOException` / `tag was lost`). Aborta de inmediato si el handle
   quedó obsoleto (`out of date` / `SecurityException`).
2. **Recovery de escritura interrumpida**: si una escritura NDEF se corta a la mitad
   (tag alejado), el contenido completo queda en `_pendingRewriteContent` y se
   reescribe íntegro al volver a acercar el **mismo** tag (match por RFID).
3. **Salvage de contenido corrupto**: ante un payload ilegible se rescata el prefijo
   válido (`_salvageCorruptedNfcContent` / `purgeCorruptedNfcContent`) en lugar de
   tratar el tag como vacío.
4. **Safeguard anti-sobrescritura**: si la decodificación NDEF falla de verdad y no
   hay contenido recuperable, **aborta** (`ERROR:LECTURA_FALLIDA`) para no pisar lo que
   pudiera haber en el tag.
5. **Reescritura íntegra en merge**: el transfer reescribe siempre el `finalContent`
   completo (destino + origen), de modo que un reintento restaura todo sin perder los
   registros acumulados.
6. **Borrado seguro** (`clearNFCTag`): se eliminó a propósito el path de "zerear"
   bloques Mifare raw porque destruía el TLV header de NDEF y dejaba el tag
   irrecuperable. Solo se borra vía NDEF / NdefFormatable (contenido mínimo `"0"`).

## 7. Riesgos de pérdida de información

Ordenados aproximadamente por severidad.

### Alto

- **Borrado del origen antes de confirmar el destino (transfer con `clearAfterRead`
  / ADB).** En `readNFC(clearAfterRead: true)` el origen se **borra dentro de la misma
  sesión de lectura**, antes de que exista un destino escrito. El dato solo vive en
  RAM (`FFAppState().nfcRead` / valor retornado). Si la app se cierra, crashea o la
  escritura/sincronización posterior falla, **la información del origen se pierde**.
  El borrado se trata como "no crítico" y el flujo continúa aunque falle.
  - Mitigación recomendada: borrar el origen **solo tras** confirmar persistencia en
    destino/servidor; o respaldar el contenido leído en SQLite antes de borrar.

- **Escritura parcial silenciosa en Mifare Classic.** En el path Mifare de
  `writeNFCTag`, los errores por bloque/autenticación se capturan y se hace `continue`,
  pero la operación **completa con `true`** sin validar `blocksWritten` contra lo
  esperado. Un tag puede quedar con datos incompletos reportando éxito.
  - Mitigación recomendada: fallar si `blocksWritten` < bloques esperados y disparar
    el recovery.

- **`_pendingRewriteContent` es volátil.** El recovery de escritura interrumpida vive
  en una variable global en memoria. Si el proceso muere antes de re-acercar el mismo
  tag, el contenido pendiente se pierde y el tag puede quedar con un NDEF parcial.
  - Mitigación recomendada: persistir el pendiente en SQLite (clave = RFID).

### Medio

- **Sin verificación por re-lectura tras escribir.** El éxito se infiere de que la
  librería no lanzó excepción, no de releer y comparar el contenido del tag. Una
  escritura "exitosa" según la API puede no reflejar el estado real del tag.

- **Tope artificial de 240 bytes en Mifare Classic.** Contenido mayor dispara el flujo
  "SOLICITAR_OTRO_TAG" (fragmentación entre dos tags). Si el segundo tag falla o el
  usuario abandona, parte del contenido no llega a escribirse.

- **`utf8.decode(..., allowMalformed: true)` en lectura Mifare/salvage.** Puede
  producir texto sustituido (U+FFFD) y aceptar como válido un contenido degradado;
  detección de fin por "muchos 0x00" es heurística y puede truncar datos legítimos.

- **Capacidad DESFire optimista (8192).** Si `GET_FREE_MEMORY` falla, se asume espacio;
  el fallo real solo aparece al escribir. `write_n_f_c_tag_direct` ni siquiera consulta
  memoria (asume 8192 fijo) — aceptable porque es solo test de capacidad.

- **`FFAppState().nfcRead` como canal de transporte.** Varias rutas comparten esta
  variable global (datos y señales tipo `ERROR:*`, `SOLICITAR_OTRO_TAG`). Flujos
  concurrentes o solapados podrían pisar el valor.

### Bajo

- **Contenido `"0"` = vacío.** Un tag cuyo contenido sea literalmente `"0"` se trata
  como vacío; es el valor de borrado intencional, pero implica que ese valor nunca
  puede ser dato real.
- **iOS sin soporte efectivo** para los caminos Android-específicos.

## 8. Severidad según el rol

- **tag-writer**: riesgo **bajo de pérdida real** — las visitas existen en SQLite y
  solo se marcan sincronizadas tras escribir el tag. El tag es transporte, no la única
  copia.
- **tag-reader**: riesgo bajo — operación de solo lectura (no borra).
- **tag-transfer / ADB-from**: riesgo **alto** cuando se borra el origen — durante el
  traspaso el tag puede ser la única copia de los datos en tránsito.

## 9. Recomendaciones prioritarias

1. No borrar el tag de origen hasta confirmar escritura en destino o ACK del servidor;
   o respaldar el contenido leído en SQLite antes del borrado.
2. Validar el conteo de bloques escritos en Mifare Classic y fallar si es incompleto.
3. Persistir `_pendingRewriteContent` para que el recovery sobreviva a reinicios.
4. Verificar por re-lectura el contenido tras escrituras críticas (transfer).
