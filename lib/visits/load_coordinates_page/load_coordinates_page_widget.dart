import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'load_coordinates_page_model.dart';
export 'load_coordinates_page_model.dart';

class LoadCoordinatesPageWidget extends StatefulWidget {
  const LoadCoordinatesPageWidget({super.key});

  static String routeName = 'LoadCoordinatesPage';
  static String routePath = '/loadCoordinatesPage';

  @override
  State<LoadCoordinatesPageWidget> createState() =>
      _LoadCoordinatesPageWidgetState();
}

class _LoadCoordinatesPageWidgetState extends State<LoadCoordinatesPageWidget> {
  late LoadCoordinatesPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoadCoordinatesPageModel());
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
                    child: custom_widgets.LoadCoordinatesVisit(
                      width: MediaQuery.sizeOf(context).width * 0.99,
                      height: MediaQuery.sizeOf(context).height * 0.99,
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
