import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'download_route_page_model.dart';
export 'download_route_page_model.dart';

class DownloadRoutePageWidget extends StatefulWidget {
  const DownloadRoutePageWidget({
    super.key,
    required this.idHeadquarter,
    bool? isTest,
  }) : this.isTest = isTest ?? false;

  final int? idHeadquarter;
  final bool isTest;

  static String routeName = 'DownloadRoutePage';
  static String routePath = '/downloadRoutePage';

  @override
  State<DownloadRoutePageWidget> createState() =>
      _DownloadRoutePageWidgetState();
}

class _DownloadRoutePageWidgetState extends State<DownloadRoutePageWidget> {
  late DownloadRoutePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DownloadRoutePageModel());
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
                    child: custom_widgets.LoadResourcesMapVisits(
                      width: MediaQuery.sizeOf(context).width * 0.99,
                      height: MediaQuery.sizeOf(context).height * 0.99,
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
