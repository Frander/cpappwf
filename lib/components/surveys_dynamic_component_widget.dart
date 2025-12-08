import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'surveys_dynamic_component_model.dart';
export 'surveys_dynamic_component_model.dart';

class SurveysDynamicComponentWidget extends StatefulWidget {
  const SurveysDynamicComponentWidget({super.key});

  @override
  State<SurveysDynamicComponentWidget> createState() =>
      _SurveysDynamicComponentWidgetState();
}

class _SurveysDynamicComponentWidgetState
    extends State<SurveysDynamicComponentWidget> {
  late SurveysDynamicComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SurveysDynamicComponentModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          image: DecorationImage(
            fit: BoxFit.cover,
            image: Image.asset(
              'assets/images/Fondoo56_Mesa-de-trabajo-1.jpg',
            ).image,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(
                0.0,
                2.0,
              ),
            )
          ],
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(5.0, 8.0, 5.0, 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                'Hello World',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: TextStyle(fontFamily: 'Roboto',
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
