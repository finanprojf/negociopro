import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../services/apartado_service.dart';
class ApartadoFormScreen extends StatefulWidget {
  const ApartadoFormScreen({super.key});

  @override
  State<ApartadoFormScreen> createState() => _ApartadoFormScreenState();
}

class _ApartadoFormScreenState extends State<ApartadoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _abonoInicialCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  DateTime? _fechaEstimada;
  String? _clienteSeleccionado;
  bool _loading = false;

  // Demo clientes
  final List<Map<String, String>> _clientes = [
    {'id': 'c1', 'nombre': 'María López'},
    {'id': 'c2', 'nombre': 'Juan Pérez'},
    {'id': 'c3', 'nombre': 'Ana García'},
  ];

  double get _montoTotal => double.tryParse(_montoCtrl.text) ?? 0;
  double get _abonoInicial => double.tryParse(_abonoInicialCtrl.text) ?? 0;
  double get _saldoPendiente => _montoTotal - _abonoInicial;

  @override
  void dispose() {
    _descripcionCtrl.dispose(); _montoCtrl.dispose();
    _abonoInicialCtrl.dispose(); _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona un cliente'),
          backgroundColor: AppColors.danger));
      return;
    }
   setState(() => _loading = true);
    await ApartadoService.crearApartado(
      clienteId: _clienteSeleccionado!,
      descripcion: _descripcionCtrl.text.trim(),
      montoTotal: _montoTotal,
      abonoInicial: _abonoInicial,
      fechaEstimada: _fechaEstimada,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Apartado creado exitosamente'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo apartado')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.colorApartados.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.colorApartados.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.colorApartados, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text(
                  'El producto quedará reservado hasta que el cliente complete el pago.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      color: AppColors.colorApartados),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            _seccion('Cliente'),
            const SizedBox(height: 12),
            _buildSelectorCliente(),
            const SizedBox(height: 20),
            _seccion('Producto / Descripción'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Descripción del apartado *',
                hintText: 'Ej: TV Samsung 55" 4K',
                prefixIcon: Icon(Icons.bookmark_outlined, color: AppColors.textMuted),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),
            _seccion('Pagos'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Monto total *',
                  prefixText: 'RD\$ ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if ((double.tryParse(v) ?? 0) <= 0) return 'Inválido';
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _abonoInicialCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Abono inicial',
                  prefixText: 'RD\$ ',
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && _abonoInicial > _montoTotal) {
                    return 'Mayor al total';
                  }
                  return null;
                },
              )),
            ]),
            if (_montoTotal > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Saldo pendiente', style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary)),
                    Text('RD\$ ${_saldoPendiente.toStringAsFixed(2)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('% inicial', style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary)),
                    Text(_montoTotal > 0
                        ? '${(_abonoInicial / _montoTotal * 100).toStringAsFixed(0)}%'
                        : '0%',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            _seccion('Fecha estimada de pago'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (fecha != null) setState(() => _fechaEstimada = fecha);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _fechaEstimada != null
                        ? _fechaEstimada!.toLocal().toString().split(' ')[0]
                        : 'Seleccionar fecha (opcional)',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                        color: _fechaEstimada != null
                            ? AppColors.textPrimary : AppColors.textMuted),
                  ),
                  const Spacer(),
                  if (_fechaEstimada != null)
                    GestureDetector(
                      onTap: () => setState(() => _fechaEstimada = null),
                      child: const Icon(Icons.clear_rounded,
                          color: AppColors.textMuted, size: 18),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            _seccion('Notas'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Notas adicionales (opcional)...',
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
                    : const Text('Crear apartado',
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

  Widget _buildSelectorCliente() {
    return DropdownButtonFormField<String>(
      value: _clienteSeleccionado,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
          color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Seleccionar cliente',
        prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
      ),
      items: _clientes.map((c) => DropdownMenuItem(
        value: c['id'],
        child: Text(c['nombre']!,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
      )).toList(),
      onChanged: (v) => setState(() => _clienteSeleccionado = v),
    );
  }
}