import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class TagHistoryWidget extends StatefulWidget {
  const TagHistoryWidget({super.key});

  @override
  State<TagHistoryWidget> createState() => _TagHistoryWidgetState();
}

class _TagHistoryWidgetState extends State<TagHistoryWidget> {
  List<Map<String, dynamic>> _tagHistory = [];
  bool _isLoading = true;
  String _selectedFilter = 'Todos'; // Filtro activo

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_selectedFilter == 'Todos') {
      return _tagHistory;
    }
    return _tagHistory
        .where((tag) => tag['type']?.toString().contains(_selectedFilter) ?? false)
        .toList();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener la ruta de la base de datos
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        debugPrint('❌ No se pudo acceder al almacenamiento externo');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final String dbPath = path.join(
        '${externalDir.path}/ClickPalmData',
        'clickpalm_database.db',
      );

      // Verificar si la base de datos existe
      if (!await File(dbPath).exists()) {
        debugPrint('⚠️ Base de datos no existe aún');
        setState(() {
          _tagHistory = [];
          _isLoading = false;
        });
        return;
      }

      // Abrir conexión a la base de datos
      final Database db = await openDatabase(dbPath);

      try {
        // Cargar historial desde SQLite ordenado por última lectura
        final List<Map<String, dynamic>> tags = await db.query(
          'Nfc_tags_history',
          orderBy: 'Last_read DESC',
        );

        // Convertir formato de SQLite a formato esperado por la UI
        final List<Map<String, dynamic>> formattedTags = tags.map((tag) {
          return {
            'id': tag['Tag_id'],
            'type': tag['Tag_type'],
            'totalSpace': tag['Total_space'] ?? 0,
            'usedSpace': tag['Used_space'] ?? 0,
            'lastRead': tag['Last_read'],
            'readCount': tag['Read_count'],
          };
        }).toList();

        setState(() {
          _tagHistory = formattedTags;
          _isLoading = false;
        });

        debugPrint('✅ Historial cargado: ${formattedTags.length} TAGs desde SQLite');
      } finally {
        await db.close();
      }
    } catch (e) {
      debugPrint('❌ Error cargando historial desde SQLite: $e');
      setState(() {
        _tagHistory = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24)),
            SizedBox(width: 12),
            Text(
              '¿Borrar historial?',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Se eliminarán todos los registros de TAGs leídos. Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Borrar',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Obtener la ruta de la base de datos
        final Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir == null) {
          debugPrint('❌ No se pudo acceder al almacenamiento externo');
          return;
        }

        final String dbPath = path.join(
          '${externalDir.path}/ClickPalmData',
          'clickpalm_database.db',
        );

        // Abrir conexión a la base de datos
        final Database db = await openDatabase(dbPath);

        try {
          // Eliminar todos los registros de la tabla
          await db.delete('Nfc_tags_history');
          debugPrint('🧹 Historial de TAGs limpiado desde SQLite');
        } finally {
          await db.close();
        }

        // Recargar historial (estará vacío)
        _loadHistory();
      } catch (e) {
        debugPrint('❌ Error limpiando historial desde SQLite: $e');
      }
    }
  }

  Color _getTagColor(String tagType) {
    if (tagType.contains('DESFire')) {
      return Color(0xFF8B5CF6); // Púrpura para DESFire
    } else if (tagType.contains('4K')) {
      return Color(0xFF3B82F6); // Azul para 4K
    } else if (tagType.contains('1K')) {
      return Color(0xFF10B981); // Verde para 1K
    }
    return Color(0xFF6B7280); // Gris para desconocido
  }

  IconData _getTagIcon(String tagType) {
    if (tagType.contains('DESFire')) {
      return Icons.verified_user; // Icono de seguridad para DESFire
    } else if (tagType.contains('4K')) {
      return Icons.storage; // Icono de almacenamiento grande
    } else if (tagType.contains('1K')) {
      return Icons.label; // Icono simple para 1K
    }
    return Icons.nfc;
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
                color: Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history, color: Color(0xFF8B5CF6), size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Historial de TAGs NFC',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          if (_tagHistory.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: Color(0xFFEF4444)),
              onPressed: _clearHistory,
              tooltip: 'Borrar historial',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            )
          : _tagHistory.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: Color(0xFF8B5CF6),
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header info
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF8B5CF6).withOpacity(0.08),
                                Color(0xFF3B82F6).withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFF8B5CF6).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF8B5CF6), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_filteredTags.length} de ${_tagHistory.length} TAG${_tagHistory.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Filtros
                        _buildFilterChips(),
                        SizedBox(height: 20),

                        // Grid de TAGs
                        _filteredTags.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.filter_alt_off,
                                        size: 60,
                                        color: Color(0xFF8B5CF6).withOpacity(0.5),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No hay TAGs de este tipo',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _filteredTags.length,
                                itemBuilder: (context, index) {
                                  final tag = _filteredTags[index];
                                  return _buildTagCard(tag);
                                },
                              ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Todos', 'key': 'Todos', 'icon': Icons.all_inclusive},
      {'label': 'DESFire 8K', 'key': 'DESFire', 'icon': Icons.verified_user},
      {'label': '4K', 'key': '4K', 'icon': Icons.storage},
      {'label': '1K', 'key': '1K', 'icon': Icons.label},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          Color chipColor;

          if (filter['key'] == 'Todos') {
            chipColor = Color(0xFF8B5CF6);
          } else if (filter['key'] == 'DESFire') {
            chipColor = Color(0xFF8B5CF6);
          } else if (filter['key'] == '4K') {
            chipColor = Color(0xFF3B82F6);
          } else {
            chipColor = Color(0xFF10B981);
          }

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor
                      : chipColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: chipColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : chipColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      filter['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Color(0xFF1E293B).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.nfc_outlined,
              size: 80,
              color: Color(0xFF8B5CF6).withOpacity(0.5),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Sin TAGs leídos',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 60),
            child: Text(
              'Lee tu primer TAG NFC para ver el historial aquí',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(int usedSpace, int totalSpace) {
    if (totalSpace == 0) {
      return SizedBox.shrink();
    }

    final percentage = (usedSpace / totalSpace * 100).clamp(0.0, 100.0);
    final freeSpace = totalSpace - usedSpace;

    return Container(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(100, 100),
            painter: PieChartPainter(
              usedPercentage: percentage / 100,
              usedColor: Color(0xFF3B82F6),
              freeColor: Color(0xFF1E293B),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${usedSpace}B',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(Map<String, dynamic> tag) {
    final tagId = tag['id'] ?? 'N/A';
    final tagType = tag['type'] ?? 'Desconocido';
    final totalSpace = tag['totalSpace'] ?? 0;
    final usedSpace = tag['usedSpace'] ?? 0;
    final lastReadStr = tag['lastRead'] ?? '';
    final readCount = tag['readCount'] ?? 0;

    DateTime? lastRead;
    try {
      lastRead = DateTime.parse(lastReadStr);
    } catch (e) {
      lastRead = null;
    }

    String formattedDate = 'N/A';
    String formattedTime = 'N/A';
    if (lastRead != null) {
      formattedDate = DateFormat('dd/MM/yyyy').format(lastRead);
      formattedTime = DateFormat('HH:mm:ss').format(lastRead);
    }

    final color = _getTagColor(tagType);
    final icon = _getTagIcon(tagType);

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono y tipo de TAG
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Spacer(),
                if (readCount > 1)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '×$readCount',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Tipo de TAG
            Text(
              tagType,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // ID del TAG
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tagId,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Gráfico de pie de espacio
            if (totalSpace > 0) ...[
              SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    _buildPieChart(usedSpace, totalSpace),
                    SizedBox(height: 4),
                    Text(
                      'Espacio: ${usedSpace}/${totalSpace} bytes',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Spacer(),

            // Última lectura
            Divider(color: Colors.white.withOpacity(0.1), height: 16),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.white60, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Painter para el gráfico de pie
class PieChartPainter extends CustomPainter {
  final double usedPercentage;
  final Color usedColor;
  final Color freeColor;

  PieChartPainter({
    required this.usedPercentage,
    required this.usedColor,
    required this.freeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Dibujar el espacio libre (círculo completo de fondo)
    final freePaint = Paint()
      ..color = freeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, freePaint);

    // Dibujar el espacio usado (arco)
    if (usedPercentage > 0) {
      final usedPaint = Paint()
        ..color = usedColor
        ..style = PaintingStyle.fill;

      final sweepAngle = 2 * math.pi * usedPercentage;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Comenzar desde arriba (12 en punto)
        sweepAngle,
        true,
        usedPaint,
      );
    }

    // Dibujar un círculo blanco en el centro para efecto de dona
    final innerPaint = Paint()
      ..color = Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, innerPaint);
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.usedPercentage != usedPercentage ||
        oldDelegate.usedColor != usedColor ||
        oldDelegate.freeColor != freeColor;
  }
}
