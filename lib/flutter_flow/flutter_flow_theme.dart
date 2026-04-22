// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';

abstract class FlutterFlowTheme {
  static FlutterFlowTheme of(BuildContext context) {
    return LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color newBg;
  late Color orange;
  late Color green;
  late Color black;

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF004629);
  late Color secondary = const Color(0xFFF19642);
  late Color tertiary = const Color(0xFFEE8B60);
  late Color alternate = const Color(0xFFF19642);
  late Color primaryText = const Color(0xFF004629);
  late Color secondaryText = const Color(0xFF57636C);
  late Color primaryBackground = const Color(0xFFF1F4F8);
  late Color secondaryBackground = const Color(0xFFFFFFFF);
  late Color accent1 = const Color(0x4C4B39EF);
  late Color accent2 = const Color(0x4D39D2C0);
  late Color accent3 = const Color(0x4DEE8B60);
  late Color accent4 = const Color(0xCCFFFFFF);
  late Color success = const Color(0xFF004629);
  late Color warning = const Color(0xFFF9CF58);
  late Color error = const Color(0xFFFF6600);
  late Color info = const Color(0xFFFFFFFF);

  late Color newBg = const Color(0xFF101827);
  late Color orange = const Color(0xFFFF6600);
  late Color green = const Color(0xFFE6FFE6);
  late Color black = const Color(0xFF000000);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'Roboto';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 64.0,
      );
  String get displayMediumFamily => 'Roboto';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 44.0,
      );
  String get displaySmallFamily => 'Roboto';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 36.0,
      );
  String get headlineLargeFamily => 'Roboto';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
      );
  String get headlineMediumFamily => 'Roboto';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 28.0,
      );
  String get headlineSmallFamily => 'Roboto';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 25.0,
      );
  String get titleLargeFamily => 'Roboto';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 21.0,
      );
  String get titleMediumFamily => 'Roboto';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => TextStyle(
        fontFamily: 'Roboto',
        color: theme.info,
        fontWeight: FontWeight.w600,
        fontSize: 19.0,
      );
  String get titleSmallFamily => 'Roboto';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => TextStyle(
        fontFamily: 'Roboto',
        color: theme.info,
        fontWeight: FontWeight.w600,
        fontSize: 17.0,
      );
  String get labelLargeFamily => 'Roboto';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => TextStyle(
        fontFamily: 'Roboto',
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 17.0,
      );
  String get labelMediumFamily => 'Roboto';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => TextStyle(
        fontFamily: 'Roboto',
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 15.0,
      );
  String get labelSmallFamily => 'Roboto';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => TextStyle(
        fontFamily: 'Roboto',
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 13.0,
      );
  String get bodyLargeFamily => 'Roboto';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 17.0,
      );
  String get bodyMediumFamily => 'Roboto';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 15.0,
      );
  String get bodySmallFamily => 'Roboto';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => TextStyle(
        fontFamily: 'Roboto',
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 13.0,
      );
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    // Usar fuentes del sistema en lugar de Google Fonts
    if (useGoogleFonts && fontFamily != null) {
      font = TextStyle(
          fontFamily: 'Roboto',
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily ?? 'Roboto',
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
