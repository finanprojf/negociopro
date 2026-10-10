import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AvatarCliente extends StatelessWidget {
  final String? fotoUrl;
  final String iniciales;
  final double radius;

  const AvatarCliente({
    super.key,
    required this.iniciales,
    this.fotoUrl,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl!) : null,
      child: fotoUrl == null
          ? Text(iniciales, style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: radius * 0.65,
              fontWeight: FontWeight.w700,
              color: AppColors.colorClientes))
          : null,
    );
  }
}
