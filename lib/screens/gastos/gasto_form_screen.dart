import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/gasto_model.dart';
import '../../services/gasto_service.dart';

class GastoFormScreen extends StatefulWidget {
  const GastoFormScreen({super.key});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _categoria = 'mercancia';
  String _metodoPago = 'efectivo';
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final gasto = GastoModel(
      id: '',
      empresaId: '',
      categoria: _categoria,
      descripcion: _descCtrl.text.trim(),
      monto: double.tryParse(_montoCtrl.text) ?? 0,
      metodoPago: _metodoPago,
      fecha: DateTime.now(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    final ok = await GastoService.guardarGasto(gasto);
    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gasto registrado'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al guardar el gasto'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _seccion('Categoría'),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: GastoModel.categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = GastoModel.categorias[i];
                  final sel = _categoria == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _categoria = cat['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.colorGastos.withValues(alpha: 0.12)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.colorGastos : AppColors.cardBorder,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(cat['label']!,
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? AppColors.colorGastos : AppColors.textSecondary,
                          )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _seccion('Descripción'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Descripción del gasto *',
                prefixIcon: Icon(Icons.description_outlined, color: AppColors.textMuted),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 20),
            _seccion('Monto'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 18,
                  fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Monto *',
                prefixText: 'RD\$ ',
                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.textMuted),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el monto';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _seccion('Método de pago'),
            const SizedBox(height: 12),
            Row(children: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
              final labels = {
                'efectivo': 'Efectivo',
                'tarjeta': 'Tarjeta',
                'transferencia': 'Transfer.',
              };
              final iconos = {
                'efectivo': Icons.payments_outlined,
                'tarjeta': Icons.credit_card_rounded,
                'transferencia': Icons.account_balance_rounded,
              };
              final sel = _metodoPago == m;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _metodoPago = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: m != 'transferencia' ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.colorGastos.withValues(alpha: 0.1)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.colorGastos : AppColors.cardBorder,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Icon(iconos[m]!,
                        color: sel ? AppColors.colorGastos : AppColors.textMuted,
                        size: 20),
                    const SizedBox(height: 4),
                    Text(labels[m]!, style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel
                            ? AppColors.colorGastos : AppColors.textSecondary)),
                  ]),
                ),
              ));
            }).toList()),
            const SizedBox(height: 20),
            _seccion('Notas (opcional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Notas adicionales...',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _guardar,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Guardar gasto',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _seccion(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));
}