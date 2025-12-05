import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/tag_admin/tag_configuration_stepper_widget.dart';
import '/tag_admin/tag_test_writer_dialog_widget.dart';
import '/tag_admin/tag_test_reader_dialog_widget.dart';
import '/tag_admin/tag_raw_reader_dialog_widget.dart';
import '/tag_admin/tag_history_widget.dart';
import '/components/nfc_clear_dialog_widget.dart';
import '/components/nfc_transfer_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TagAdminCenterWidget extends StatefulWidget {
  const TagAdminCenterWidget({super.key});

  @override
  State<TagAdminCenterWidget> createState() => _TagAdminCenterWidgetState();
}

class _TagAdminCenterWidgetState extends State<TagAdminCenterWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.nfc, color: Color(0xFF3B82F6), size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Centro de Administración NFC',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header description
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3B82F6).withOpacity(0.08),
                    Color(0xFF8B5CF6).withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configure y administre sus tags NFC antes de usarlos en campo',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Main action - Configurar TAG
            ScaleTransition(
              scale: _pulseAnimation,
              child: _buildMainActionCard(),
            ),
            SizedBox(height: 24),

            // Section title
            Text(
              'Operaciones de TAG',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),

            // Grid of actions
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildActionCard(
                  icon: Icons.edit,
                  title: 'Escribir Prueba',
                  subtitle: 'Escribir datos de prueba',
                  color: Color(0xFF10B981),
                  onTap: () => _showTestWriter(),
                ),
                _buildActionCard(
                  icon: Icons.visibility,
                  title: 'Leer TAG',
                  subtitle: 'Ver contenido del TAG',
                  color: Color(0xFF3B82F6),
                  onTap: () => _showTestReader(),
                ),
                _buildActionCard(
                  icon: Icons.swap_horiz,
                  title: 'Transferir',
                  subtitle: 'Copiar entre TAGs',
                  color: Color(0xFF8B5CF6),
                  onTap: () => _showTagTransfer(),
                ),
                _buildActionCard(
                  icon: Icons.code,
                  title: 'Ver Raw',
                  subtitle: 'Contenido técnico',
                  color: Color(0xFFF59E0B),
                  onTap: () => _showRawReader(),
                ),
                _buildActionCard(
                  icon: Icons.cleaning_services,
                  title: 'Limpiar TAG',
                  subtitle: 'Borrar contenido',
                  color: Color(0xFFEF4444),
                  onTap: () => _showClearTag(),
                ),
                _buildActionCard(
                  icon: Icons.history,
                  title: 'Historial',
                  subtitle: 'TAGs registrados',
                  color: Color(0xFF8B5CF6),
                  onTap: () => _showTagHistory(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionCard() {
    return InkWell(
      onTap: () => _showConfigurationStepper(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3B82F6).withOpacity(0.5),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.settings_suggest, color: Colors.white, size: 40),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurar TAG',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Flujo completo de verificación y limpieza',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigurationStepper() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagConfigurationStepperWidget(),
    );
  }

  void _showTestWriter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagTestWriterDialogWidget(),
    );
  }

  void _showTestReader() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagTestReaderDialogWidget(),
    );
  }

  void _showTagTransfer() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NfcTransferDialogWidget(),
      ),
    );
  }

  void _showRawReader() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagRawReaderDialogWidget(),
    );
  }

  void _showClearTag() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NfcClearDialogWidget(),
    );
  }

  void _showTagHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TagHistoryWidget(),
      ),
    );
  }
}
