import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'config_voice_page_model.dart';
export 'config_voice_page_model.dart';

class ConfigVoicePageWidget extends StatefulWidget {
  const ConfigVoicePageWidget({super.key});

  static String routeName = 'ConfigVoicePage';
  static String routePath = '/configVoicePage';

  @override
  State<ConfigVoicePageWidget> createState() => _ConfigVoicePageWidgetState();
}

class _ConfigVoicePageWidgetState extends State<ConfigVoicePageWidget> {
  late ConfigVoicePageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigVoicePageModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth  = MediaQuery.of(context).size.width;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      body: custom_widgets.LoadResourcesVoiceModel(
        width: screenWidth,
        height: screenHeight,
        showInlineMode: false,
        onModelReady: () async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Modelo IA listo para usar'),
                  ],
                ),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onSkip: () async {
          if (context.mounted) context.pop();
        },
      ),
    );
  }
}
