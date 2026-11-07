import 'package:flutter/material.dart';

/// Utilidad de diseño responsivo.
/// Breakpoint tablet: lado más corto >= 600dp
class R {
  R._();

  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.shortestSide >= 600;

  static bool isLandscape(BuildContext ctx) =>
      MediaQuery.of(ctx).orientation == Orientation.landscape;

  /// Número de columnas para grids
  static int cols(BuildContext ctx, {required int phone, required int tablet}) =>
      isTablet(ctx) ? tablet : phone;

  /// Padding horizontal mayor en tablet
  static EdgeInsets hPad(BuildContext ctx,
      {double phone = 16, double tablet = 32}) =>
      EdgeInsets.symmetric(
          horizontal: isTablet(ctx) ? tablet : phone);

  /// Envuelve el contenido centrándolo y limitando ancho en tablet
  static Widget maxBox(BuildContext ctx, Widget child,
      {double maxW = 760}) {
    if (!isTablet(ctx)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }

  /// Widget que centra solo en tablet
  static Widget centered(BuildContext ctx, {required Widget child,
      double maxW = 760}) {
    if (!isTablet(ctx)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}
