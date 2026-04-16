import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

/// TileProvider que sirve tiles de ortomosaicos desde el filesystem (modo offline puro).
/// Ruta: {basePath}/{relativePath}/{z}/{x}/{y}.png
/// Si un tile no existe, retorna un tile transparente.
class OrtomosaicFileTileProvider extends TileProvider {
  final String basePath;
  final String relativePath;

  OrtomosaicFileTileProvider({
    required this.basePath,
    required this.relativePath,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final filePath = p.join(
      basePath,
      relativePath,
      coordinates.z.toString(),
      coordinates.x.toString(),
      '${coordinates.y}.png',
    );
    return _FileTileImageProvider(filePath: filePath);
  }
}

/// ImageProvider que carga tiles desde el filesystem de forma asíncrona.
class _FileTileImageProvider extends ImageProvider<_FileTileImageProvider> {
  final String filePath;

  const _FileTileImageProvider({required this.filePath});

  @override
  Future<_FileTileImageProvider> obtainKey(ImageConfiguration config) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _FileTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'FileTile($filePath)',
    );
  }

  Future<ui.Codec> _loadAsync(
      _FileTileImageProvider key, ImageDecoderCallback decode) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      }
    } catch (e) {
      debugPrint('⚠️ FileTileProvider error ($filePath): $e');
    }

    return _transparentTile(decode);
  }

  Future<ui.Codec> _transparentTile(ImageDecoderCallback decode) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 256, 256),
      ui.Paint()..color = const ui.Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _FileTileImageProvider && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}

/// Bounds geográficos para restringir el TileLayer al área del ortomosaico
class OrtomosaicBounds {
  final double west, south, east, north;
  const OrtomosaicBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  LatLngBounds toLatLngBounds() => LatLngBounds(
        LatLng(south, west),
        LatLng(north, east),
      );
}
