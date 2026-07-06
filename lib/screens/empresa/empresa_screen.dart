import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../suscripcion/suscripcion_screen.dart';
import 'package:google_fonts/google_fonts.dart';
class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({super.key});

  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
 final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _lemaCtrl = TextEditingController();
  bool _loading = false;
@override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId != null) {
        final res = await SupabaseService.client
            .from('empresas')
            .select()
            .eq('id', empresaId)
            .single();
        if (mounted) {
          setState(() {
            _nombreCtrl.text = res['nombre'] ?? '';
            _telefonoCtrl.text = res['telefono'] ?? '';
            _whatsappCtrl.text = res['whatsapp'] ?? '';
            _direccionCtrl.text = res['direccion'] ?? '';
            _lemaCtrl.text = res['lema'] ?? '';
          });
        }
      }
    } catch (e) {
      print('❌ Error cargar empresa: $e');
    }
  }
  @override
  void dispose() {
    _nombreCtrl.dispose(); _telefonoCtrl.dispose();
    _whatsappCtrl.dispose(); _direccionCtrl.dispose(); _lemaCtrl.dispose();
    super.dispose();
  }

 Future<void> _guardar() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId != null) {
        await SupabaseService.client.from('empresas').update({
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'whatsapp': _whatsappCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'lema': _lemaCtrl.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', empresaId);
      }
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Información actualizada'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      print('❌ Error guardar empresa: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mi negocio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildLogoSection(),
          const SizedBox(height: 24),
          _seccion('Información del negocio'),
          const SizedBox(height: 12),
          _campo(_nombreCtrl, 'Nombre del negocio', Icons.store_outlined),
          const SizedBox(height: 12),
          _campo(_telefonoCtrl, 'Teléfono', Icons.phone_outlined,
              tipo: TextInputType.phone),
          const SizedBox(height: 12),
          _campo(_whatsappCtrl, 'WhatsApp', Icons.chat_rounded,
              tipo: TextInputType.phone),
          const SizedBox(height: 12),
          _campo(_direccionCtrl, 'Dirección', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _campo(_lemaCtrl, 'Lema / eslogan', Icons.format_quote_rounded),
          const SizedBox(height: 24),
          _seccion('Cuenta'),
          const SizedBox(height: 12),
          _buildOpcionCuenta(Icons.lock_outlined, 'Cambiar contraseña', () {}),
          const SizedBox(height: 8),
          _buildOpcionCuenta(Icons.email_outlined, 'Cambiar correo', () {}),
          const SizedBox(height: 8),
          _buildOpcionCuenta(Icons.notifications_outlined, 'Notificaciones', () {}),
          const SizedBox(height: 24),
          _seccion('Plan'),
          const SizedBox(height: 12),
          _buildPlanCard(),
          const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SuscripcionScreen())),
    icon: const Icon(Icons.workspace_premium_rounded),
    label: Text('Ver planes de suscripción',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
  ),
),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Guardar cambios',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _confirmarLogout(),
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              label: const Text('Cerrar sesión',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
                      fontWeight: FontWeight.w600, color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(child: Stack(children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.store_rounded, color: Colors.white, size: 50),
      ),
      Positioned(
        bottom: 0, right: 0,
        child: GestureDetector(
          onTap: () {}, // TODO: image_picker para logo
          child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    ]));
  }

  Widget _buildOpcionCuenta(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 14, color: AppColors.textPrimary))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.primary,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan Básico', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            Text('Actualiza a Pro para desbloquear\ntodas las funciones',
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        )),
        TextButton(
          onPressed: () {},
          child: const Text('Mejorar',
              style: TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]),
    );
  }

  Widget _seccion(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {TextInputType tipo = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      ),
    );
  }

  void _confirmarLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('¿Seguro que quieres cerrar sesión?',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
           await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Cerrar sesión',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}