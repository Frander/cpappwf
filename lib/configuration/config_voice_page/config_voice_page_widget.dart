import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main download/status widget
                    SizedBox(
                      width: double.infinity,
                      child: custom_widgets.LoadResourcesVoiceModel(
                        width: double.infinity,
                        showInlineMode: false,
                        onModelReady: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 20),
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
                        },
                        onSkip: () async {
                          if (context.mounted) context.pop();
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info section
                    _buildInfoSection(),

                    const SizedBox(height: 24),

                    // Requirements section
                    _buildRequirementsSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración de Voz',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Asistente IA on-device',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: Color(0xFF0D9488), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sobre el asistente',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          icon: Icons.mic_rounded,
          color: const Color(0xFF0D9488),
          title: 'Narración en tiempo real',
          description:
              'El asistente lee en voz alta la dirección y distancia a las palmas más cercanas mientras navegas con la brújula.',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.psychology_rounded,
          color: const Color(0xFF6366F1),
          title: 'IA generativa on-device',
          description:
              'Usa Gemma 3 1B (modelo de Google) ejecutado directamente en tu dispositivo. No envía datos a internet.',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.language_rounded,
          color: const Color(0xFFF59E0B),
          title: 'Español colombiano',
          description:
              'Las frases son generadas y leídas en español colombiano, adaptadas al contexto de trabajo en campo.',
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requisitos del dispositivo',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildRequirementRow(
                  Icons.android_rounded, 'Android 7.0+', 'minSdk 24', true),
              const Divider(color: Color(0xFF334155), height: 20),
              _buildRequirementRow(
                  Icons.storage_rounded, 'Almacenamiento libre', '~1 GB', true),
              const Divider(color: Color(0xFF334155), height: 20),
              _buildRequirementRow(
                  Icons.memory_rounded, 'RAM disponible', '~2 GB', true),
              const Divider(color: Color(0xFF334155), height: 20),
              _buildRequirementRow(
                  Icons.speed_rounded, 'GPU (opcional)', 'Acelera la IA', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
      IconData icon, String label, String value, bool required) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0D9488), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: required
                ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                : const Color(0xFF0D9488).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            required ? 'Req.' : 'Opc.',
            style: TextStyle(
                color: required
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF0D9488),
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
