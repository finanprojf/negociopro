import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreNegocioCtrl = TextEditingController();
  final _nombreDuenoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _verPass = false;

  // País seleccionado (nombre, código de área, emoji bandera)
  _Pais _paisSel = const _Pais('República Dominicana', '+1', '🇩🇴');

  @override
  void dispose() {
    _nombreNegocioCtrl.dispose();
    _nombreDuenoCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // 1. Crear usuario en Supabase Auth
      final res = await Supabase.instance.client.auth.signUp(
        email: _correoCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (res.user == null) throw Exception('No se pudo crear el usuario');

      final userId = res.user!.id;

      // 2. Crear empresa con trial de 30 días incluido en el insert
      final ahora = DateTime.now().toUtc();
      final fechaFin = ahora.add(const Duration(days: 30));
      final empresaRes = await Supabase.instance.client
          .from('empresas')
          .insert({
            'nombre': _nombreNegocioCtrl.text.trim(),
            'telefono': '${_paisSel.codigo} ${_telefonoCtrl.text.trim()}'.trim(),
            'pais': _paisSel.nombre,
            'plan_activo': 'trial',
            'suscripcion_vence': fechaFin.toIso8601String(),
          })
          .select()
          .single();

      final empresaId = empresaRes['id'];

      // 3. Crear usuario vinculado a la empresa
      await Supabase.instance.client.from('usuarios').insert({
        'id': userId,
        'empresa_id': empresaId,
        'nombre': _nombreDuenoCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
        'rol': 'admin',
      });

      // 4. Crear registro de suscripción
      try {
        await Supabase.instance.client.from('suscripciones').insert({
          'empresa_id': empresaId,
          'plan': 'trial',
          'estado': 'activo',
          'fecha_inicio': ahora.toIso8601String(),
          'fecha_fin': fechaFin.toIso8601String(),
        });
      } catch (_) {} // No crítico — empresas ya tiene el trial
if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
      // AuthWrapper redirige automáticamente
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
   } catch (e) {
     
      if (mounted) _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildSeccion('Tu negocio'),
                const SizedBox(height: 12),
                _buildCampo(_nombreNegocioCtrl, 'Nombre del negocio',
                    Icons.store_outlined, 'Ej: Colmado La Esperanza'),
                const SizedBox(height: 16),
                _buildSelectorPais(),
                const SizedBox(height: 10),
                _buildCampoTelefono(),
                const SizedBox(height: 24),
                _buildSeccion('Tu cuenta'),
                const SizedBox(height: 12),
                _buildCampo(_nombreDuenoCtrl, 'Tu nombre',
                    Icons.person_outline, 'Ej: Juan Pérez'),
                const SizedBox(height: 16),
                _buildCampo(_correoCtrl, 'Correo electrónico',
                    Icons.email_outlined, 'ejemplo@correo.com',
                    tipo: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildCampoPass(),
                const SizedBox(height: 16),
                _buildCampoConfirmPass(),
                const SizedBox(height: 32),
                _buildBotonRegistrar(),
                const SizedBox(height: 16),
                _buildTerminos(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.store_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NegocioPro',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'por FinanPro Solutions',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Registra tu negocio gratis',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Comienza a gestionar tu negocio en minutos',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccion(String titulo) {
    return Text(
      titulo.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCampo(
    TextEditingController ctrl, String label, IconData icon, String hint,
    {TextInputType tipo = TextInputType.text}
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }

  Widget _buildCampoPass() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: !_verPass,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Contraseña',
        prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textMuted),
        suffixIcon: IconButton(
          icon: Icon(
            _verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted,
          ),
          onPressed: () => setState(() => _verPass = !_verPass),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Ingresa una contraseña';
        if (v.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
    );
  }

  Widget _buildCampoConfirmPass() {
    return TextFormField(
      controller: _confirmPassCtrl,
      obscureText: !_verPass,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Confirmar contraseña',
        prefixIcon: Icon(Icons.lock_outlined, color: AppColors.textMuted),
      ),
      validator: (v) {
        if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
        return null;
      },
    );
  }

  Widget _buildBotonRegistrar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _registrar,
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'Crear cuenta gratis',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildTerminos() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            'Al registrarte aceptas nuestros ',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://vitrina-web-beta.vercel.app/privacidad');
              try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
            },
            child: const Text(
              'Términos de uso',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: AppColors.primary, decoration: TextDecoration.underline),
            ),
          ),
          const Text(
            ' y ',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://vitrina-web-beta.vercel.app/privacidad');
              try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
            },
            child: const Text(
              'Política de privacidad.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: AppColors.primary, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de país ────────────────────────────────────────────
  Widget _buildSelectorPais() {
    return DropdownButtonFormField<String>(
      value: _paisSel.nombre,
      decoration: InputDecoration(
        labelText: 'País',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Text(_paisSel.bandera, style: const TextStyle(fontSize: 20)),
        ),
      ),
      items: _paises.map((p) => DropdownMenuItem(
        value: p.nombre,
        child: Text('${p.bandera}  ${p.nombre}  (${p.codigo})',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
      )).toList(),
      onChanged: (nombre) {
        final p = _paises.firstWhere((x) => x.nombre == nombre, orElse: () => _paises.first);
        setState(() => _paisSel = p);
      },
    );
  }

  // ── Campo teléfono — el usuario escribe su número normal ───────────
  Widget _buildCampoTelefono() {
    return TextFormField(
      controller: _telefonoCtrl,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Teléfono',
        prefixIcon: Icon(Icons.phone_outlined),
        hintText: 'Ej: 8091234567',
        hintStyle: TextStyle(fontFamily: 'Poppins',
            color: AppColors.textMuted, fontSize: 13),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Ingresa tu teléfono';
        return null;
      },
    );
  }

}


// ── Modelo de país ────────────────────────────────────────────────────────────
class _Pais {
  final String nombre, codigo, bandera;
  const _Pais(this.nombre, this.codigo, this.bandera);
}

const _paises = [
  _Pais('República Dominicana', '+1',    '🇩🇴'),
  _Pais('Estados Unidos',       '+1',    '🇺🇸'),
  _Pais('México',               '+52',   '🇲🇽'),
  _Pais('Guatemala',            '+502',  '🇬🇹'),
  _Pais('Honduras',             '+504',  '🇭🇳'),
  _Pais('El Salvador',          '+503',  '🇸🇻'),
  _Pais('Nicaragua',            '+505',  '🇳🇮'),
  _Pais('Costa Rica',           '+506',  '🇨🇷'),
  _Pais('Panamá',               '+507',  '🇵🇦'),
  _Pais('Colombia',             '+57',   '🇨🇴'),
  _Pais('Venezuela',            '+58',   '🇻🇪'),
  _Pais('Ecuador',              '+593',  '🇪🇨'),
  _Pais('Perú',                 '+51',   '🇵🇪'),
  _Pais('Bolivia',              '+591',  '🇧🇴'),
  _Pais('Chile',                '+56',   '🇨🇱'),
  _Pais('Argentina',            '+54',   '🇦🇷'),
  _Pais('Uruguay',              '+598',  '🇺🇾'),
  _Pais('Paraguay',             '+595',  '🇵🇾'),
  _Pais('Brasil',               '+55',   '🇧🇷'),
  _Pais('Puerto Rico',          '+1',    '🇵🇷'),
  _Pais('Cuba',                 '+53',   '🇨🇺'),
  _Pais('España',               '+34',   '🇪🇸'),
];
