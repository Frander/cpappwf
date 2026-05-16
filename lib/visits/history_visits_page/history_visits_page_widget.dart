import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'history_visits_page_model.dart';
export 'history_visits_page_model.dart';

class HistoryVisitsPageWidget extends StatefulWidget {
  const HistoryVisitsPageWidget({super.key});

  static String routeName = 'HistoryVisitsPage';
  static String routePath = '/historyVisitsPage';

  @override
  State<HistoryVisitsPageWidget> createState() =>
      _HistoryVisitsPageWidgetState();
}

class _HistoryVisitsPageWidgetState extends State<HistoryVisitsPageWidget> {
  late HistoryVisitsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistoryVisitsPageModel());
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
        backgroundColor: const Color(0xFF003420),
        body: SafeArea(
          top: true,
          child: custom_widgets.HistoryVisitsForm(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
          ),
        ),
      ),
    );
  }
}
