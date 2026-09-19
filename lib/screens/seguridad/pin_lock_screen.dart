import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/pin_service.dart';

/// Pantalla de desbloqueo con PIN.
/// Se usa como overlay cuando la app está bloqueada.
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _entrada = '';
  bool _error = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _press(String digit) {
    if (_entrada.length >= 6) return;
    setState(() { _entrada += digit; _error = false; });
    if (_entrada.length == 4 || _entrada.length == 6) _verificar();
  }

  void _borrar() {
    if (_entrada.isEmpty) return;
    setState(() => _entrada = _entrada.substring(0, _entrada.length - 1));
  }

  Future<void> _verificar() async {
    final ok = await PinService.verificarPin(_entrada);
    if (ok) {
      HapticFeedback.lightImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      setState(() { _error = true; _entrada = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F7B5B),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 60),
          const Icon(Icons.lock_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('App bloqueada',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                  fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(_error ? 'PIN incorrecto' : 'Ingresa tu PIN',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  color: _error
                      ? Colors.redAccent[100]
                      : Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 40),
          // Dots
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0), child: child),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final lleno = i < _entrada.length;
                  // Si el PIN es de 4, solo mostramos 4 dots
                  if (i >= 4 && !lleno) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lleno ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                    ),
                  );
                })),
          ),
          const SizedBox(height: 50),
          // Teclado numérico
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(children: [
                for (final row in [
                  ['1','2','3'],
                  ['4','5','6'],
                  ['7','8','9'],
                  ['','0','⌫'],
                ])
                  Expanded(
                    child: Row(children: row.map((d) => Expanded(
                      child: d.isEmpty
                          ? const SizedBox()
                          : _PinKey(
                          label: d,
                          onTap: d == '⌫' ? _borrar : () => _press(d),
                          isBackspace: d == '⌫',
                        ),
                    )).toList()),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;
  const _PinKey({required this.label, required this.onTap, this.isBackspace = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 22)
              : Text(label,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                  fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }
}
