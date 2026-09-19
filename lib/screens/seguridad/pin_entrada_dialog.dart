import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/pin_service.dart';

/// Diálogo de PIN para acciones rápidas (requiere autorización del dueño).
/// Retorna true si el PIN fue correcto, false si canceló.
Future<bool> mostrarDialogoPinRapido(BuildContext context, {String titulo = 'Autorización requerida'}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinRapidoDialog(titulo: titulo),
  );
  return result ?? false;
}

class _PinRapidoDialog extends StatefulWidget {
  final String titulo;
  const _PinRapidoDialog({required this.titulo});
  @override State<_PinRapidoDialog> createState() => _PinRapidoDialogState();
}

class _PinRapidoDialogState extends State<_PinRapidoDialog>
    with SingleTickerProviderStateMixin {
  String _entrada = '';
  bool _error = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _press(String d) {
    if (_entrada.length >= 6) return;
    setState(() { _entrada += d; _error = false; });
    if (_entrada.length == 4 || _entrada.length == 6) _verificar();
  }

  void _borrar() {
    if (_entrada.isEmpty) return;
    setState(() => _entrada = _entrada.substring(0, _entrada.length - 1));
  }

  Future<void> _verificar() async {
    final ok = await PinService.verificarPinRapido(_entrada);
    if (ok) { if (mounted) Navigator.pop(context, true); }
    else {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      setState(() { _error = true; _entrada = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.primary, size: 36),
          const SizedBox(height: 12),
          Text(widget.titulo,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_error ? 'PIN incorrecto, intenta de nuevo' : 'Ingresa el PIN de acciones',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  color: _error ? AppColors.danger : AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) =>
                Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final lleno = i < _entrada.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lleno ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: lleno
                          ? AppColors.primary
                          : AppColors.cardBorder, width: 1.5),
                    ),
                  );
                })),
          ),
          const SizedBox(height: 20),
          // Mini teclado
          for (final row in [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']])
            Row(children: row.map((d) => Expanded(
              child: d.isEmpty ? const SizedBox() :
              InkWell(
                onTap: d == '⌫' ? _borrar : () => _press(d),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: d == '⌫'
                        ? const Icon(Icons.backspace_outlined,
                        color: AppColors.textSecondary, size: 18)
                        : Text(d, style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 20, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                  ),
                ),
              ),
            )).toList()),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}
