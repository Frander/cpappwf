import '/flutter_flow/flutter_flow_util.dart';
import 'video_capture_component_widget.dart' show VideoCaptureComponentWidget;
import 'package:flutter/material.dart';

class VideoCaptureComponentModel
    extends FlutterFlowModel<VideoCaptureComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Variable para almacenar el path del video capturado
  String? videoPath;

  // Variable para saber si ya se capturó un video
  bool isVideoTaken = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
