import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_visits_page_model.dart';
export 'map_visits_page_model.dart';

class MapVisitsPageWidget extends StatefulWidget {
  const MapVisitsPageWidget({super.key});

  static String routeName = 'MapVisitsPage';
  static String routePath = '/mapVisitsPage';

  @override
  State<MapVisitsPageWidget> createState() => _MapVisitsPageWidgetState();
}

class _MapVisitsPageWidgetState extends State<MapVisitsPageWidget> {
  late MapVisitsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MapVisitsPageModel());
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
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.99,
                    height: MediaQuery.sizeOf(context).height * 0.99,
                    child: custom_widgets.OfflineMapTrackerVisits(
                      width: MediaQuery.sizeOf(context).width * 0.99,
                      height: MediaQuery.sizeOf(context).height * 0.99,
                      mapFilePath: FFAppState().pathPmtiles,
                      isTestMode: true,
                      authToken: getJsonField(
                        FFAppState().loginResponse,
                        r'''$.token''',
                      ).toString(),
                      headquarters: FFAppState().headquartersSelectedList,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
