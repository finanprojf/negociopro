import 'package:flutter/material.dart';

class AppColors {
  // === MARCA NEGOCIOPRO ===
  // Verde esmeralda — confianza, crecimiento, negocios saludables
  static const Color primary = Color(0xFF0F7B5B);
  static const Color primaryLight = Color(0xFF1AAE82);
  static const Color primaryDark = Color(0xFF085240);
  static const Color primarySurface = Color(0xFFE8F7F2);

  // Acento dorado — premium, prosperidad
  static const Color accent = Color(0xFFD4A017);
  static const Color accentLight = Color(0xFFF0C040);
  static const Color accentSurface = Color(0xFFFDF8E8);

  // === FONDOS ===
  static const Color background = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F4F2);
  static const Color cardBorder = Color(0xFFE2EAE6);

  // === TEXTOS ===
  static const Color textPrimary = Color(0xFF1A2E28);
  static const Color textSecondary = Color(0xFF4A6B61);
  static const Color textMuted = Color(0xFF8AADA4);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // === ESTADOS ===
  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFDBEAFE);

  // === MÓDULOS (color único por sección) ===
  static const Color colorInventario   = Color(0xFF7C3AED);
  static const Color colorVentas       = Color(0xFF0891B2);
  static const Color colorClientes     = Color(0xFF0F7B5B);
  static const Color colorFiado        = Color(0xFFDC2626);
  static const Color colorApartados    = Color(0xFFD97706);
  static const Color colorGastos       = Color(0xFF64748B);
  static const Color colorReportes     = Color(0xFF1D4ED8);
  static const Color colorFidelizacion = Color(0xFFDB2777);
}
/// Paleta oscura de NegocioPro — misma identidad de marca, contraste premium.
class AppColorsDark {
  // === MARCA (mismos verdes/dorado, ajustados para oscuro) ===
  static const Color primary      = Color(0xFF1AAE82);  // más brillante sobre fondo oscuro
  static const Color primaryLight = Color(0xFF26C896);
  static const Color primaryDark  = Color(0xFF0F7B5B);
  static const Color primarySurface = Color(0xFF0D2B22); // verde muy oscuro tenue

  static const Color accent        = Color(0xFFEDBA30);
  static const Color accentLight   = Color(0xFFF5CC60);
  static const Color accentSurface = Color(0xFF2A2210);

  // === FONDOS ===
  static const Color background  = Color(0xFF0F1412);  // negro verdoso premium
  static const Color surface     = Color(0xFF1A2420);  // tarjetas
  static const Color surfaceAlt  = Color(0xFF1F2C28);  // inputs
  static const Color cardBorder  = Color(0xFF2A3C36);

  // === TEXTOS ===
  static const Color textPrimary   = Color(0xFFE8F0EC);
  static const Color textSecondary = Color(0xFF8FBFB0);
  static const Color textMuted     = Color(0xFF4D6B62);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // === ESTADOS ===
  static const Color success        = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFF0D2A1A);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFF2A1F08);
  static const Color danger         = Color(0xFFEF4444);
  static const Color dangerSurface  = Color(0xFF2A1010);
  static const Color info           = Color(0xFF60A5FA);
  static const Color infoSurface    = Color(0xFF0D1A2E);

  // === MÓDULOS ===
  static const Color colorInventario   = Color(0xFF9F7AEA);
  static const Color colorVentas       = Color(0xFF22D3EE);
  static const Color colorClientes     = Color(0xFF1AAE82);
  static const Color colorFiado        = Color(0xFFEF4444);
  static const Color colorApartados    = Color(0xFFFBBF24);
  static const Color colorGastos       = Color(0xFF94A3B8);
  static const Color colorReportes     = Color(0xFF60A5FA);
  static const Color colorFidelizacion = Color(0xFFF472B6);
}
