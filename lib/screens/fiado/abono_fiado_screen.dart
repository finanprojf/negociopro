import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/fiado_model.dart';
import '../../utils/formatters.dart';
import '../../services/fiado_service.dart';

class AbonoFiadoScreen extends StatefulWidget {
  final FiadoModel fiado;
  const AbonoFiadoScreen({super.key, required this.fiado});

  @override
  State<AbonoFiadoScreen> createState() => _AbonoFiadoScreenState();
}

class _AbonoFiadoScreenState extends State<AbonoFiadoScreen> {
  final _montoCtrl = TextEditingController();
  String _metodoPago = 'efectivo';
  bool _loading = false;

  double get _monto => double.tryParse(_montoCtrl.text) ?? 0;
  double get _montoReal => _monto.clamp(0, widget.fiado.saldoPendiente);
  double get _nuevoSaldo =>
      (widget.fiado.saldoPendiente - _montoReal).clamp(0, double.infinity);
  bool get _completaElPago => _monto >= widget.fiado.saldoPendiente;
  double get _vuelto =>
      _monto > widget.fiado.saldoPendiente ? _monto - widget.fiado.saldoPendiente : 0;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresa un monto válido'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _loading = true);
    final ok = await FiadoService.registrarAbono(
      widget.fiado.id,
      widget.fiado.clienteId,
      _montoReal,
      _metodoPago,
    );
    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_completaElPago
              ? '¡Fiado pagado completamente!'
              : 'Abono de ${AppFormatters.moneda(_montoReal)} registrado'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al registrar el abono'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fiado;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Abono — ${f.clienteNombre ?? "Cliente"}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Resumen del fiado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.colorFiado.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.colorFiado.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Text(f.clienteNombre ?? '',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              if (f.clienteTelefono != null) ...[
                const SizedBox(height: 4),
                Text(f.clienteTelefono!, style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13,
                    color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _InfoCol('Original',
                    AppFormatters.moneda(f.montoOriginal), AppColors.textPrimary),
                _InfoCol('Pagado',
                    AppFormatters.moneda(f.montoPagado), AppColors.success),
                _InfoCol('Pendiente',
                    AppFormatters.moneda(f.saldoPendiente), AppColors.colorFiado),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: f.porcentajePagado,
                  backgroundColor: AppColors.cardBorder,
                  color: AppColors.colorFiado,
                  minHeight: 8,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Campo de monto
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 28, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Monto del abono',
              prefixText: 'RD\$ ',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 12),

          // Atajos rápidos
          Row(children: [
            Expanded(child: _MontoBtn('50%',
                f.saldoPendiente * 0.5, _montoCtrl, () => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _MontoBtn('Todo',
                f.saldoPendiente, _montoCtrl, () => setState(() {}))),
          ]),
          const SizedBox(height: 16),

          // Preview en tiempo real
          if (_monto > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                // Monto que se aplica a la deuda
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Se aplica a deuda',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 13, color: AppColors.primary)),
                  Text(AppFormatters.moneda(_montoReal),
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 10),
                // Saldo que queda
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Le quedan al cliente',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    _nuevoSaldo <= 0 ? 'Deuda saldada ✓' : AppFormatters.moneda(_nuevoSaldo),
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: _nuevoSaldo <= 0 ? AppColors.success : AppColors.colorFiado),
                  ),
                ]),
              ]),
            ),
            // Vuelto — visible en tiempo real cuando paga de más
            if (_vuelto > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Row(children: [
                    Icon(Icons.currency_exchange_rounded,
                        color: AppColors.success, size: 22),
                    SizedBox(width: 10),
                    Text('Vuelto al cliente',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                  ]),
                  Text(AppFormatters.moneda(_vuelto),
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: AppColors.success)),
                ]),
              ),
            ],
          ],
          const SizedBox(height: 20),

          // Método de pago
          Align(
            alignment: Alignment.centerLeft,
            child: Text('MÉTODO DE PAGO',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          Row(children: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
            final iconos = {
              'efectivo': Icons.payments_outlined,
              'tarjeta': Icons.credit_card_rounded,
              'transferencia': Icons.account_balance_rounded,
            };
            final labels = {
              'efectivo': 'Efectivo',
              'tarjeta': 'Tarjeta',
              'transferencia': 'Transfer.',
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
                      ? AppColors.colorFiado.withValues(alpha: 0.1)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? AppColors.colorFiado : AppColors.cardBorder,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  Icon(iconos[m]!,
                      color: sel ? AppColors.colorFiado : AppColors.textMuted,
                      size: 20),
                  const SizedBox(height: 4),
                  Text(labels[m]!, style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? AppColors.colorFiado : AppColors.textSecondary)),
                ]),
              ),
            ));
          }).toList()),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _registrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _completaElPago
                    ? AppColors.success : AppColors.colorFiado,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _completaElPago
                          ? 'Cancelar deuda completa'
                          : 'Registrar abono',
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String label; final String valor; final Color color;
  const _InfoCol(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 10, color: AppColors.textMuted)),
    const SizedBox(height: 2),
    Text(valor, style: TextStyle(fontFamily: 'Poppins',
        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _MontoBtn extends StatelessWidget {
  final String label; final double monto;
  final TextEditingController ctrl; final VoidCallback onTap;
  const _MontoBtn(this.label, this.monto, this.ctrl, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { ctrl.text = monto.toStringAsFixed(2); onTap(); },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Center(child: Text(label, style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 13,
          fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
    ),
  );
}