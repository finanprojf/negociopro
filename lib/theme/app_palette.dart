import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Paleta consciente del tema. Usar en build():
///   final pal = AppPalette.of(context);
///   color: pal.surface
class AppPalette {
  final Color background, surface, surfaceAlt, cardBorder;
  final Color textPrimary, textSecondary, textMuted, textOnPrimary;
  final Color primary, primaryLight, primaryDark, primarySurface;
  final Color accent, accentLight, accentSurface;
  final Color success, successSurface;
  final Color warning, warningSurface;
  final Color danger, dangerSurface;
  final Color info, infoSurface;
  final Color colorInventario, colorVentas, colorClientes, colorFiado;
  final Color colorApartados, colorGastos, colorReportes, colorFidelizacion;

  const AppPalette._({
    required this.background, required this.surface,
    required this.surfaceAlt, required this.cardBorder,
    required this.textPrimary, required this.textSecondary,
    required this.textMuted, required this.textOnPrimary,
    required this.primary, required this.primaryLight,
    required this.primaryDark, required this.primarySurface,
    required this.accent, required this.accentLight, required this.accentSurface,
    required this.success, required this.successSurface,
    required this.warning, required this.warningSurface,
    required this.danger, required this.dangerSurface,
    required this.info, required this.infoSurface,
    required this.colorInventario, required this.colorVentas,
    required this.colorClientes, required this.colorFiado,
    required this.colorApartados, required this.colorGastos,
    required this.colorReportes, required this.colorFidelizacion,
  });

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _dark
        : _light;
  }

  static const AppPalette _light = AppPalette._(
    background: AppColors.background, surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt, cardBorder: AppColors.cardBorder,
    textPrimary: AppColors.textPrimary, textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted, textOnPrimary: AppColors.textOnPrimary,
    primary: AppColors.primary, primaryLight: AppColors.primaryLight,
    primaryDark: AppColors.primaryDark, primarySurface: AppColors.primarySurface,
    accent: AppColors.accent, accentLight: AppColors.accentLight,
    accentSurface: AppColors.accentSurface,
    success: AppColors.success, successSurface: AppColors.successSurface,
    warning: AppColors.warning, warningSurface: AppColors.warningSurface,
    danger: AppColors.danger, dangerSurface: AppColors.dangerSurface,
    info: AppColors.info, infoSurface: AppColors.infoSurface,
    colorInventario: AppColors.colorInventario, colorVentas: AppColors.colorVentas,
    colorClientes: AppColors.colorClientes, colorFiado: AppColors.colorFiado,
    colorApartados: AppColors.colorApartados, colorGastos: AppColors.colorGastos,
    colorReportes: AppColors.colorReportes, colorFidelizacion: AppColors.colorFidelizacion,
  );

  static const AppPalette _dark = AppPalette._(
    background: AppColorsDark.background, surface: AppColorsDark.surface,
    surfaceAlt: AppColorsDark.surfaceAlt, cardBorder: AppColorsDark.cardBorder,
    textPrimary: AppColorsDark.textPrimary, textSecondary: AppColorsDark.textSecondary,
    textMuted: AppColorsDark.textMuted, textOnPrimary: AppColorsDark.textOnPrimary,
    primary: AppColorsDark.primary, primaryLight: AppColorsDark.primaryLight,
    primaryDark: AppColorsDark.primaryDark, primarySurface: AppColorsDark.primarySurface,
    accent: AppColorsDark.accent, accentLight: AppColorsDark.accentLight,
    accentSurface: AppColorsDark.accentSurface,
    success: AppColorsDark.success, successSurface: AppColorsDark.successSurface,
    warning: AppColorsDark.warning, warningSurface: AppColorsDark.warningSurface,
    danger: AppColorsDark.danger, dangerSurface: AppColorsDark.dangerSurface,
    info: AppColorsDark.info, infoSurface: AppColorsDark.infoSurface,
    colorInventario: AppColorsDark.colorInventario, colorVentas: AppColorsDark.colorVentas,
    colorClientes: AppColorsDark.colorClientes, colorFiado: AppColorsDark.colorFiado,
    colorApartados: AppColorsDark.colorApartados, colorGastos: AppColorsDark.colorGastos,
    colorReportes: AppColorsDark.colorReportes, colorFidelizacion: AppColorsDark.colorFidelizacion,
  );
}
