import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/gasto_model.dart';
import '../../utils/formatters.dart';
import '../../services/gasto_service.dart';
import 'package:google_fonts/google_fonts.dart';
class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  List<GastoModel> _gastos = [];
  bool _loading = true;

  double get _totalHoy {
    final hoy = DateTime.now();
    return _gastos.where((g) =>
        g.fecha.day == hoy.day && g.fecha.month == hoy.month && g.fecha.year == hoy.year)
        .fold(0, (s, g) => s + g.monto);
  }

  double get _totalMes {
    final ahora = DateTime.now();
    return _gastos.where((g) =>
        g.fecha.month == ahora.month && g.fecha.year == ahora.year)
        .fold(0, (s, g) => s + g.monto);
  }

  @override
  void initState() { super.initState(); _cargar(); }

 Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final gastos = await GastoService.getGastos();
      if (mounted) setState(() {
        _gastos = gastos;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error gastos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gastos')),
      body: Column(children: [
        _buildResumen(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _gastos.isEmpty ? _buildEmpty() : _buildLista(),
        ),
      ]),
     floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormGasto(context),
        backgroundColor: AppColors.primary,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            Text('Gasto', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        _Col(AppFormatters.moneda(_totalHoy), 'Hoy', AppColors.colorGastos),
        Container(width: 1, height: 40, color: AppColors.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 16)),
        _Col(AppFormatters.moneda(_totalMes), 'Este mes', AppColors.colorFiado),
      ]),
    );
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _gastos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _GastoTile(gasto: _gastos[i]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Sin gastos registrados', style: TextStyle(fontFamily: 'Poppins',
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]),
  );

  void _mostrarFormGasto(BuildContext context) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoriaSeleccionada = 'mercancia';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nuevo gasto', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            // Categorías
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: GastoModel.categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = GastoModel.categorias[i];
                  final sel = categoriaSeleccionada == cat['id'];
                  return GestureDetector(
                    onTap: () => setModal(() => categoriaSeleccionada = cat['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.colorGastos.withValues(alpha: 0.12) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.colorGastos : AppColors.cardBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text(cat['label']!, style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? AppColors.colorGastos : AppColors.textSecondary)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'RD\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
           child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await GastoService.guardarGasto(GastoModel(
                    id: '',
                    empresaId: '',
                    categoria: categoriaSeleccionada,
                    descripcion: descCtrl.text.isEmpty ? 'Sin descripción' : descCtrl.text,
                    monto: double.tryParse(montoCtrl.text) ?? 0,
                    fecha: DateTime.now(),
                  ));
                  await _cargar();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Gasto registrado'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                
                
                },
                child: const Text('Guardar gasto', style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String valor; final String label; final Color color;
  const _Col(this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(valor, style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
        fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 12, color: AppColors.textMuted)),
  ]));
}

class _GastoTile extends StatelessWidget {
  final GastoModel gasto;
  const _GastoTile({required this.gasto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.colorGastos.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: AppColors.colorGastos, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gasto.descripcion, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
              child: Text(gasto.categoriaLabel, style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            Text(AppFormatters.fechaCorta(gasto.fecha),
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ])),
        Text(AppFormatters.moneda(gasto.monto),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.colorFiado)),
      ]),
    );
  }
}