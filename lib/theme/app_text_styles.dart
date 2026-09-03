import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String _font = 'Poppins';

  // Títulos de pantalla
  static const TextStyle screenTitle = TextStyle(
    fontFamily: _font,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  // Títulos de sección / card
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Nombre de producto/cliente (lista)
  static const TextStyle itemTitle = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Subtítulo / descripción
  static const TextStyle subtitle = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Valores monetarios grandes (dashboard)
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: _font,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // Valores monetarios medianos
  static const TextStyle moneyMedium = TextStyle(
    fontFamily: _font,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Label pequeño (etiquetas, categorías)
  static const TextStyle label = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );

  // Botón
  static const TextStyle button = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.2,
  );

  // Texto muted / hint
  static const TextStyle muted = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );
}