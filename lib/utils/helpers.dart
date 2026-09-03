import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class AppHelpers {

  /// Mostrar snackbar de éxito
  static void showSuccess(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Mostrar snackbar de error
  static void showError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Abrir WhatsApp con mensaje
  static Future<void> abrirWhatsApp(String telefono, String mensaje) async {
    final numero = telefono.replaceAll(RegExp(r'[\s\-()]'), '');
    final numConCodigo = numero.startsWith('1') ? numero : '1$numero';
    final url = Uri.parse(
        'https://wa.me/$numConCodigo?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  /// Diálogo de confirmación genérico
  static Future<bool> confirmar(BuildContext context,
      {required String titulo, required String mensaje,
       String botonConfirmar = 'Confirmar',
       Color colorConfirmar = AppColors.danger}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(mensaje, style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(botonConfirmar, style: TextStyle(
                color: colorConfirmar, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Generar mensaje de recordatorio de fiado para WhatsApp
  static String mensajeRecordatorioFiado({
    required String nombreCliente,
    required double saldoPendiente,
    required String nombreNegocio,
  }) {
    return '¡Hola $nombreCliente! 👋\n\n'
        'Le recordamos que tiene un saldo pendiente de '
        '*RD\$ ${saldoPendiente.toStringAsFixed(2)}* en $nombreNegocio.\n\n'
        'Si tiene alguna duda, no dude en contactarnos. ¡Gracias! 🙏';
  }

  /// Mensaje de confirmación de apartado
  static String mensajeApartado({
    required String nombreCliente,
    required String descripcion,
    required double saldoPendiente,
    required String nombreNegocio,
  }) {
    return '¡Hola $nombreCliente! 🎉\n\n'
        'Tu apartado de *$descripcion* está activo en $nombreNegocio.\n\n'
        'Saldo pendiente: *RD\$ ${saldoPendiente.toStringAsFixed(2)}*\n\n'
        'Sigue abonando para completar tu apartado. ¡Gracias! 😊';
  }
}