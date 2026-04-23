import 'dart:io';

/// Helpers semánticos para detectar tipo de plataforma.
///
/// Evita que los checks queden escritos como `Platform.isWindows` (que olvidan
/// Linux y macOS) o como `!Platform.isWindows` (que entra en Linux y crashea
/// con plugins que sólo existen en móvil).
class Platforms {
  /// true en Android o iOS (plataformas con NFC, GPS, sensores, cámara, BLE, etc).
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// true en Windows, Linux o macOS (desktop sin los plugins móviles).
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
