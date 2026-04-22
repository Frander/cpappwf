# Script mejorado para reemplazar GoogleFonts
# Incluye: inter, interTight, jetBrainsMono, orbitron, robotoMono

$files = @(
    # Lote 10
    "lib\components\keyboard_num_component_widget.dart",
    "lib\components\info_dialog_widget.dart",
    "lib\components\date_picker_component_widget.dart",
    "lib\components\device_registration_form_widget.dart",
    "lib\components\device_registration_loading_widget.dart",
    # Lote 11
    "lib\components\counter_control_component_widget.dart",
    "lib\components\calibration_required_dialog_widget.dart",
    "lib\components\company_selection_grid_widget.dart",
    "lib\components\calculate_coordenates_install_component_widget.dart",
    "lib\components\calibrate_compass_component_widget.dart",
    # Lote 12
    "lib\components\calculate_coordenates_component_widget.dart",
    "lib\components\advanced_sync_dialog_widget.dart",
    "lib\add_product_page\add_product_page_widget.dart",
    "lib\activities_page\activities_page_widget.dart",
    "lib\activities\steps_main\steps_main_widget.dart",
    # Lote 13
    "lib\activities\steps_activity_main\steps_activity_main_widget.dart",
    "lib\activities\status_activity_main\status_activity_main_widget.dart",
    "lib\custom_code\actions\export_dynamic_p_d_f.dart",
    "lib\custom_code\actions\export_thermal_p_d_f.dart"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $content = Get-Content -Path $file -Raw -Encoding UTF8
        $content = $content -replace "import 'package:google_fonts/google_fonts.dart';", ""
        $content = $content -replace "GoogleFonts\.inter\(", "TextStyle(fontFamily: 'Roboto',"
        $content = $content -replace "GoogleFonts\.interTight\(", "TextStyle(fontFamily: 'Roboto',"
        $content = $content -replace "GoogleFonts\.jetBrainsMono\(", "TextStyle(fontFamily: 'Roboto Mono',"
        $content = $content -replace "GoogleFonts\.orbitron\(", "TextStyle(fontFamily: 'Roboto',"
        $content = $content -replace "GoogleFonts\.robotoMono\(", "TextStyle(fontFamily: 'Roboto Mono',"
        Set-Content -Path $file -Value $content -NoNewline -Encoding UTF8
        Write-Host "Reemplazo completado en $file"
    } else {
        Write-Host "Archivo no encontrado: $file"
    }
}
