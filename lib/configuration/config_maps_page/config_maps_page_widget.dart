import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config_maps_page_model.dart';
export 'config_maps_page_model.dart';

class ConfigMapsPageWidget extends StatefulWidget {
  const ConfigMapsPageWidget({super.key});

  static String routeName = 'ConfigMapsPage';
  static String routePath = '/configMapsPage';

  @override
  State<ConfigMapsPageWidget> createState() => _ConfigMapsPageWidgetState();
}

class _ConfigMapsPageWidgetState extends State<ConfigMapsPageWidget> {
  late ConfigMapsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigMapsPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF101827),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          width: 1.0,
                        ),
                      ),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width * 0.99,
                        height: MediaQuery.sizeOf(context).height * 0.99,
                        child: custom_widgets.LoadResourcesMapTiles(
                          width: MediaQuery.sizeOf(context).width * 0.99,
                          height: MediaQuery.sizeOf(context).height * 0.99,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
