import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import 'register_screen.dart';
import '../dashboard/dashboard_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _verPass = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
    await Supabase.instance.client.auth.signInWithPassword(
        email: _correoCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
   } on AuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                _buildLogo(),
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildCampoCorreo(),
                const SizedBox(height: 16),
                _buildCampoPassword(),
                const SizedBox(height: 12),
                _buildOlvidePassword(),
                const SizedBox(height: 32),
                _buildBotonLogin(),
                const SizedBox(height: 24),
                _buildIrARegistro(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.store_rounded, color: Colors.white, size: 44),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bienvenido',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Inicia sesión para gestionar tu negocio',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCampoCorreo() {
    return TextFormField(
      controller: _correoCtrl,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Correo electrónico',
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
        if (!v.contains('@')) return 'Correo inválido';
        return null;
      },
    );
  }

  Widget _buildCampoPassword() {
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
        if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
        if (v.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
    );
  }

  Widget _buildOlvidePassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _mostrarResetPassword,
        child: const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBotonLogin() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildIrARegistro() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '¿No tienes cuenta? ',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
            child: const Text(
              'Registrar negocio',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarResetPassword() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restablecer contraseña',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Te enviaremos un enlace a tu correo para crear una nueva contraseña.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.resetPasswordForEmail(ctrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace enviado. Revisa tu correo.')),
                    );
                  }
                },
                child: const Text('Enviar enlace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}