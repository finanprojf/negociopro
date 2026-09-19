import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/pin_service.dart';

/// Pantalla de configuración de PINs (seguridad y acciones rápidas).
class PinConfiguracionScreen extends StatefulWidget {
  const PinConfiguracionScreen({super.key});
  @override State<PinConfiguracionScreen> createState() => _PinConfiguracionScreenState();
}

class _PinConfiguracionScreenState extends State<PinConfiguracionScreen> {
  bool _pinSegHabilitado = false;
  bool _pinRapHabilitado = false;
  String _modoBloqueo = PinService.modoBloqueado;
  bool _loading = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final h = await PinService.habilitado;
    final r = await PinService.rapidoHabilitado;
    final m = await PinService.modo;
    if (mounted) setState(() {
      _pinSegHabilitado = h; _pinRapHabilitado = r; _modoBloqueo = m; _loading = false;
    });
  }

  Future<void> _configurarPin({required bool esRapido}) async {
    // Paso 1: ingresa PIN nuevo
    final pin1 = await _pedirPin(context, titulo: esRapido
        ? 'Crea tu PIN de acciones'
        : 'Crea tu PIN de seguridad', confirmar: false);
    if (pin1 == null || pin1.length < 4) return;

    // Paso 2: confirmar
    final pin2 = await _pedirPin(context,
        titulo: 'Confirma tu PIN', confirmar: true);
    if (pin2 == null) return;

    if (pin1 != pin2) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Los PINs no coinciden'), backgroundColor: AppColors.danger));
      return;
    }

    if (esRapido) {
      await PinService.guardarPinRapido(pin1);
      setState(() => _pinRapHabilitado = true);
    } else {
      await PinService.guardarPin(pin1);
      setState(() => _pinSegHabilitado = true);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(esRapido ? 'PIN de acciones guardado' : 'PIN de seguridad activado'),
        backgroundColor: AppColors.success));
  }

  Future<void> _desactivarPin({required bool esRapido}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(esRapido ? 'Desactivar PIN de acciones' : 'Desactivar PIN de seguridad'),
        content: const Text('¿Estás seguro? El PIN será eliminado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    if (esRapido) {
      await PinService.desactivarRapido();
      setState(() => _pinRapHabilitado = false);
    } else {
      await PinService.desactivar();
      setState(() => _pinSegHabilitado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Seguridad y PIN')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(padding: const EdgeInsets.all(16), children: [

          // ── PIN DE SEGURIDAD ──
          _Section('PIN de seguridad', Icons.lock_rounded),
          const SizedBox(height: 8),
          _Card(child: Column(children: [
            _Row(
              icon: Icons.security_rounded,
              title: 'Bloqueo de app',
              subtitle: _pinSegHabilitado
                  ? 'Activo — la app pide PIN para abrirse'
                  : 'Desactivado',
              trailing: Switch(
                value: _pinSegHabilitado,
                activeColor: AppColors.primary,
                onChanged: (v) => v
                    ? _configurarPin(esRapido: false)
                    : _desactivarPin(esRapido: false),
              ),
            ),
            if (_pinSegHabilitado) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('¿Cuándo bloquear?',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(height: 8),
              _OpcionModo(
                label: 'Al ir al fondo / bloquear pantalla',
                icono: Icons.phone_android_rounded,
                seleccionado: _modoBloqueo == PinService.modoBloqueado,
                onTap: () async {
                  await PinService.setModo(PinService.modoBloqueado);
                  setState(() => _modoBloqueo = PinService.modoBloqueado);
                },
              ),
              const SizedBox(height: 6),
              _OpcionModo(
                label: 'Solo al cerrar la app completamente',
                icono: Icons.close_rounded,
                seleccionado: _modoBloqueo == PinService.modoCerrar,
                onTap: () async {
                  await PinService.setModo(PinService.modoCerrar);
                  setState(() => _modoBloqueo = PinService.modoCerrar);
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _configurarPin(esRapido: false),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Cambiar PIN'),
              ),
            ],
          ])),

          const SizedBox(height: 20),

          // ── PIN DE ACCIONES RÁPIDAS ──
          _Section('PIN de acciones rápidas', Icons.flash_on_rounded),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Protege operaciones sensibles como anular ventas, aplicar descuentos o cerrar el día.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: AppColors.textMuted),
            ),
          ),
          _Card(child: Column(children: [
            _Row(
              icon: Icons.bolt_rounded,
              title: 'PIN de acciones',
              subtitle: _pinRapHabilitado
                  ? 'Activo — se pedirá antes de acciones sensibles'
                  : 'Desactivado',
              trailing: Switch(
                value: _pinRapHabilitado,
                activeColor: AppColors.primary,
                onChanged: (v) => v
                    ? _configurarPin(esRapido: true)
                    : _desactivarPin(esRapido: true),
              ),
            ),
            if (_pinRapHabilitado) ...[
              const Divider(height: 1),
              TextButton.icon(
                onPressed: () => _configurarPin(esRapido: true),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Cambiar PIN'),
              ),
            ],
          ])),
        ]),
    );
  }
}

// ── Helpers ──

class _Section extends StatelessWidget {
  final String title; final IconData icon;
  const _Section(this.title, this.icon);
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 15,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder)),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: child,
  );
}

class _Row extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Widget trailing;
  const _Row({required this.icon, required this.title,
    required this.subtitle, required this.trailing});
  @override Widget build(BuildContext context) => ListTile(
    leading: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20)),
    title: Text(title, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 12, color: AppColors.textMuted)),
    trailing: trailing,
  );
}

class _OpcionModo extends StatelessWidget {
  final String label; final IconData icono;
  final bool seleccionado; final VoidCallback onTap;
  const _OpcionModo({required this.label, required this.icono,
    required this.seleccionado, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: seleccionado ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: seleccionado ? AppColors.primary : AppColors.cardBorder,
            width: seleccionado ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icono, size: 20,
            color: seleccionado ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
            color: seleccionado ? AppColors.primary : AppColors.textSecondary))),
        if (seleccionado)
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
      ]),
    ),
  );
}

// Diálogo para ingresar un PIN (4 dígitos)
Future<String?> _pedirPin(BuildContext context,
    {required String titulo, required bool confirmar}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinInputDialog(titulo: titulo),
  );
}

class _PinInputDialog extends StatefulWidget {
  final String titulo;
  const _PinInputDialog({required this.titulo});
  @override State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  String _pin = '';

  void _press(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) Navigator.pop(context, _pin);
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.titulo,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('4 dígitos', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final lleno = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lleno ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: lleno
                        ? AppColors.primary : AppColors.cardBorder, width: 1.5),
                  ),
                );
              })),
          const SizedBox(height: 20),
          for (final row in [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']])
            Row(children: row.map((d) => Expanded(
              child: d.isEmpty ? const SizedBox() :
              InkWell(
                onTap: d == '⌫' ? _borrar : () => _press(d),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44, margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(child: d == '⌫'
                      ? const Icon(Icons.backspace_outlined,
                      color: AppColors.textSecondary, size: 18)
                      : Text(d, style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 20, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary))),
                ),
              ),
            )).toList()),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}
