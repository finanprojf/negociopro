import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../suscripcion/suscripcion_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../admin/admin_screen.dart';
import 'impresora_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
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
  bool _subiendoLogo = false;
  String? _logoUrl;

bool _esAdmin = false;

@override
void initState() {
  super.initState();
  _cargarDatos();
  _verificarAdmin();
}

Future<void> _verificarAdmin() async {
  try {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    final res = await SupabaseService.client
        .from('usuarios')
        .select('es_admin')
        .eq('id', userId)
        .single();
    if (mounted) setState(() => _esAdmin = res['es_admin'] == true);
  } catch (_) {}
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
            _logoUrl = res['logo_url'];
          });
        }
      }
    } catch (_) {}
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
    } catch (_) {
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
          _buildOpcionCuenta(Icons.lock_outlined, 'Cambiar contraseña', _cambiarContrasena),
          const SizedBox(height: 8),
          _buildOpcionCuenta(Icons.email_outlined, 'Cambiar correo', _cambiarCorreo),
          const SizedBox(height: 8),
          _buildOpcionCuenta(Icons.notifications_outlined, 'Notificaciones', _notificaciones),
          const SizedBox(height: 8),
          _buildOpcionCuenta(Icons.print_rounded, 'Impresora Térmica', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImpresoraScreen()))),
          const SizedBox(height: 8),
          _buildOpcionCuenta(
            Icons.delete_forever_rounded,
            'Eliminar mi cuenta',
            _iniciarFlujoBaja,
            esDestructivo: true,
          ),
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
          if (_esAdmin) ...[
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen())),
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: Text('Panel Admin', style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorFiado,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
    return Center(child: Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: _subirLogo,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: _subiendoLogo
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CachedNetworkImage(
                        imageUrl: _logoUrl!,
                        fit: BoxFit.cover,
                        width: 100, height: 100,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.store_rounded, color: Colors.white, size: 50),
                      ),
                    )
                  : const Icon(Icons.store_rounded, color: Colors.white, size: 50),
        ),
      ),
      Positioned(
        bottom: -4, right: -4,
        child: GestureDetector(
          onTap: _subirLogo,
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

  Future<void> _subirLogo() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Cámara'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final xfile = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 512);
    if (xfile == null) return;

    setState(() => _subiendoLogo = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      final bytes = await File(xfile.path).readAsBytes();
      final ext = xfile.path.split('.').last.toLowerCase();
      final fileName = 'logo_$empresaId.$ext';

      await SupabaseService.client.storage
          .from('negociopro-logos')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));

      final url = SupabaseService.client.storage
          .from('negociopro-logos')
          .getPublicUrl(fileName);

      final urlConTimestamp = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseService.client
          .from('empresas')
          .update({'logo_url': urlConTimestamp})
          .eq('id', empresaId);

      if (mounted) setState(() => _logoUrl = urlConTimestamp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Logo actualizado ✓'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir logo: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    final ctrl = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar contraseña',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La contraseña no puede estar vacía'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (ctrl.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    try {
      await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: ctrl.text.trim()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Contraseña actualizada'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _cambiarCorreo() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar correo',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Nuevo correo electrónico'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar enlace')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!ctrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresa un correo válido'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    try {
      await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: ctrl.text.trim()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Revisa tu correo nuevo para confirmar el cambio'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating));
    }
  }

  void _notificaciones() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Las notificaciones se configurarán próximamente'),
        behavior: SnackBarBehavior.floating));
  }

  // ─── FLUJO ELIMINAR CUENTA ───────────────────────────────────────────────

  void _iniciarFlujoBaja() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EliminarCuentaSheet(),
    ).then((eliminado) {
      if (eliminado == true && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget _buildOpcionCuenta(IconData icon, String label, VoidCallback onTap,
      {bool esDestructivo = false}) {
    final color = esDestructivo ? AppColors.danger : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: esDestructivo
              ? AppColors.danger.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esDestructivo
                ? AppColors.danger.withValues(alpha: 0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Poppins',
              fontSize: 14, color: color, fontWeight: esDestructivo
                  ? FontWeight.w600 : FontWeight.normal))),
          Icon(Icons.chevron_right_rounded,
              color: esDestructivo ? AppColors.danger.withValues(alpha: 0.5)
                  : AppColors.textMuted,
              size: 20),
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

// ═══════════════════════════════════════════════════════════════════════════
//  SHEET: Wizard de 3 pasos para eliminar cuenta
// ═══════════════════════════════════════════════════════════════════════════

class _EliminarCuentaSheet extends StatefulWidget {
  const _EliminarCuentaSheet();

  @override
  State<_EliminarCuentaSheet> createState() => _EliminarCuentaSheetState();
}

class _EliminarCuentaSheetState extends State<_EliminarCuentaSheet> {
  int _paso = 0; // 0 = razón, 1 = comentario, 2 = confirmación final
  String? _razonSeleccionada;
  final _comentarioCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _eliminando = false;
  bool _confirmError = false;

  static const _razones = [
    ('🐛', 'La app tiene errores o fallas'),
    ('💸', 'Es muy cara / no puedo pagar'),
    ('🏪', 'Ya cerré mi negocio'),
    ('🔄', 'Uso otra aplicación'),
    ('😕', 'No le encuentro utilidad'),
    ('🔒', 'Preocupaciones de privacidad'),
    ('🤷', 'Otro motivo'),
  ];

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _paso == 0
              ? _buildPasoRazon()
              : _paso == 1
                  ? _buildPasoComentario()
                  : _buildPasoConfirmacion(),
        ),
      ),
    );
  }

  // ── Paso 0: seleccionar razón ──────────────────────────────────────────

  Widget _buildPasoRazon() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        const SizedBox(height: 16),
        const Icon(Icons.help_outline_rounded,
            color: AppColors.textMuted, size: 40),
        const SizedBox(height: 12),
        const Text('¿Por qué quieres eliminar\ntu cuenta?',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Tu opinión nos ayuda a mejorar NegocioPro',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ..._razones.map((r) {
          final selected = _razonSeleccionada == r.$2;
          return GestureDetector(
            onTap: () => setState(() => _razonSeleccionada = r.$2),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.danger : AppColors.cardBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Text(r.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(r.$2,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? AppColors.danger : AppColors.textPrimary))),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.danger, size: 18),
              ]),
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Cancelar',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _razonSeleccionada == null
                  ? null
                  : () => setState(() => _paso = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continuar',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Paso 1: comentario opcional ────────────────────────────────────────

  Widget _buildPasoComentario() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        const SizedBox(height: 16),
        const Icon(Icons.chat_bubble_outline_rounded,
            color: AppColors.textMuted, size: 40),
        const SizedBox(height: 12),
        const Text('¿Algo más que quieras\ncontarnos?',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Opcional — pero nos ayuda mucho',
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        TextField(
          controller: _comentarioCtrl,
          maxLines: 4,
          maxLength: 300,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Cuéntanos qué podríamos mejorar...',
            hintStyle: const TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _paso = 0),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Atrás',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _paso = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continuar',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Paso 2: confirmación final ─────────────────────────────────────────

  Widget _buildPasoConfirmacion() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        const SizedBox(height: 16),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 36),
        ),
        const SizedBox(height: 14),
        const Text('Esto es permanente',
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.danger)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdvertenciaItem('Se eliminarán todos tus productos e inventario'),
              _AdvertenciaItem('Se eliminarán tus ventas y reportes'),
              _AdvertenciaItem('Se eliminarán tus clientes y fiados'),
              _AdvertenciaItem('Se eliminarán tus encargos y gastos'),
              _AdvertenciaItem('Esta acción NO se puede deshacer'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Escribe ELIMINAR para confirmar:',
              style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          style: const TextStyle(fontFamily: 'Poppins',
              fontWeight: FontWeight.w700, letterSpacing: 1.5),
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            if (_confirmError) setState(() => _confirmError = false);
          },
          decoration: InputDecoration(
            hintText: 'ELIMINAR',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _confirmError ? AppColors.danger : Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger, width: 2),
            ),
            errorText: _confirmError ? 'Escribe exactamente: ELIMINAR' : null,
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _eliminando ? null : () => setState(() => _paso = 1),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Atrás',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _eliminando ? null : _eliminarCuenta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _eliminando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Eliminar cuenta',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _eliminarCuenta() async {
    if (_confirmCtrl.text.trim().toUpperCase() != 'ELIMINAR') {
      setState(() => _confirmError = true);
      return;
    }
    setState(() => _eliminando = true);
    try {
      final userId = SupabaseService.userId;
      // Guardar feedback antes de eliminar (best-effort)
      if (userId != null) {
        try {
          await SupabaseService.client.from('feedback_bajas').insert({
            'user_id': userId,
            'razon': _razonSeleccionada,
            'comentario': _comentarioCtrl.text.trim().isEmpty
                ? null : _comentarioCtrl.text.trim(),
            'app': 'negociopro',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {/* ignorar si la tabla no existe */}
      }
      // Cerrar sesión y eliminar cuenta en Supabase Auth
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _eliminando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Widget _handle() => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class _AdvertenciaItem extends StatelessWidget {
  final String texto;
  const _AdvertenciaItem(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⚠️ ', style: TextStyle(fontSize: 12)),
        Expanded(child: Text(texto,
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 12, color: AppColors.danger))),
      ]),
    );
  }
}
