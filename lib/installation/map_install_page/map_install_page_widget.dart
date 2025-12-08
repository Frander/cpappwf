import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_install_page_model.dart';
export 'map_install_page_model.dart';

class MapInstallPageWidget extends StatefulWidget {
  const MapInstallPageWidget({
    super.key,
    required this.idHeadquarter,
    bool? isTest,
  }) : this.isTest = isTest ?? false;

  final int? idHeadquarter;
  final bool isTest;

  static String routeName = 'MapInstallPage';
  static String routePath = '/mapInstallPage';

  @override
  State<MapInstallPageWidget> createState() => _MapInstallPageWidgetState();
}

class _MapInstallPageWidgetState extends State<MapInstallPageWidget> {
  late MapInstallPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MapInstallPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
                        child: custom_widgets.OfflineMapTracker(
                          width: MediaQuery.sizeOf(context).width * 0.99,
                          height: MediaQuery.sizeOf(context).height * 0.99,
                          mapFilePath: FFAppState().pathPmtiles,
                          idHeadquarter: widget!.idHeadquarter,
                          isTestMode: widget!.isTest,
                          authToken: getJsonField(
                            FFAppState().loginResponse,
                            r'''$.token''',
                          ).toString(),
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
