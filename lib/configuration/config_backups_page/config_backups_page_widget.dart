import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'config_backups_page_model.dart';
export 'config_backups_page_model.dart';

class ConfigBackupsPageWidget extends StatefulWidget {
  const ConfigBackupsPageWidget({super.key});

  static String routeName = 'ConfigBackupsPage';
  static String routePath = '/configBackupsPage';

  @override
  State<ConfigBackupsPageWidget> createState() =>
      _ConfigBackupsPageWidgetState();
}

class _ConfigBackupsPageWidgetState extends State<ConfigBackupsPageWidget> {
  late ConfigBackupsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigBackupsPageModel());
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
            decoration: const BoxDecoration(
              color: Color(0xFF101827),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          width: 1.0,
                        ),
                      ),
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width * 0.99,
                        height: MediaQuery.sizeOf(context).height * 0.99,
                        child: custom_widgets.LoadBackupsForm(
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
