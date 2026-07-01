import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import '../../services/supabase_service.dart';
import 'fiado_cliente_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ventas/pos_screen.dart';

class _ClienteFiado {
  final ClienteModel cliente;
  final double totalPendiente;
  final int cantidadFiados;

  _ClienteFiado({
    required this.cliente,
    required this.totalPendiente,
    required this.cantidadFiados,
  });
}

class FiadoScreen extends StatefulWidget {
  const FiadoScreen({super.key});

  @override
  State<FiadoScreen> createState() => _FiadoScreenState();
}

class _FiadoScreenState extends State<FiadoScreen> {
  List<_ClienteFiado> _clientes = [];
  List<_ClienteFiado> _filtrados = [];
  bool _loading = true;
  String _filtro = 'activo';
  final _searchCtrl = TextEditingController();

  double get _totalGeneral =>
      _clientes.fold(0, (s, c) => s + c.totalPendiente);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      var query = SupabaseService.client
          .from('fiados')
          .select('*, clientes(id, nombre, telefono, cedula)')
          .eq('empresa_id', empresaId);

      if (_filtro != 'todos') {
        query = query.eq('estado', _filtro);
      }

      final res = await query.order('created_at', ascending: false);

      final Map<String, _ClienteFiado> mapa = {};
      for (final f in res) {
        if (f['clientes'] == null) continue;
        final clienteData = f['clientes'] as Map<String, dynamic>;
        final clienteId = clienteData['id'] as String;
        final saldo = (f['saldo_pendiente'] as num).toDouble();

        if (mapa.containsKey(clienteId)) {
          mapa[clienteId] = _ClienteFiado(
            cliente: mapa[clienteId]!.cliente,
            totalPendiente: mapa[clienteId]!.totalPendiente + saldo,
            cantidadFiados: mapa[clienteId]!.cantidadFiados + 1,
          );
        } else {
          mapa[clienteId] = _ClienteFiado(
            cliente: ClienteModel(
              id: clienteId,
              empresaId: empresaId,
              nombre: clienteData['nombre'] ?? '',
              telefono: clienteData['telefono'],
              cedula: clienteData['cedula'],
            ),
            totalPendiente: saldo,
            cantidadFiados: 1,
          );
        }
      }

      if (mounted) {
        setState(() {
          _clientes = mapa.values.toList()
            ..sort((a, b) => b.totalPendiente.compareTo(a.totalPendiente));
          _aplicarFiltros();
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Error fiados: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _aplicarFiltros() {
    final q = _searchCtrl.text.toLowerCase();
    _filtrados = q.isEmpty
        ? List.from(_clientes)
        : _clientes.where((c) =>
            c.cliente.nombre.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fiado')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PosScreen())),
        backgroundColor: AppColors.colorFiado,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake_outlined, color: Colors.white, size: 20),
            Text('Fiado', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
          ],
        ),
      ),
      body: Column(children: [
        _buildResumenTotal(),
        _buildBuscadorFiltros(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
              : _filtrados.isEmpty
                  ? _buildEmpty()
                  : _buildLista(),
        ),
      ]),
    );
  }

  Widget _buildResumenTotal() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorFiado.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.colorFiado.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total en fiado', style: TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(AppFormatters.moneda(_totalGeneral),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                  fontWeight: FontWeight.w700, color: AppColors.colorFiado)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_clientes.length}', style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 22,
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Text('clientes', style: TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }

  Widget _buildBuscadorFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(_aplicarFiltros),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Buscar cliente...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Chip('Activos', 'activo', _filtro, AppColors.colorFiado,
                (v) { setState(() => _filtro = v); _cargar(); }),
            const SizedBox(width: 8),
            _Chip('Vencidos', 'vencido', _filtro, AppColors.danger,
                (v) { setState(() => _filtro = v); _cargar(); }),
            const SizedBox(width: 8),
            _Chip('Pagados', 'pagado', _filtro, AppColors.success,
                (v) { setState(() => _filtro = v); _cargar(); }),
            const SizedBox(width: 8),
            _Chip('Todos', 'todos', _filtro, AppColors.primary,
                (v) { setState(() => _filtro = v); _cargar(); }),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLista() {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.colorFiado,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filtrados.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ClienteFiadoCard(
          item: _filtrados[i],
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => FiadoClienteScreen(
                    cliente: _filtrados[i].cliente)));
            _cargar();
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Sin fiados', style: TextStyle(fontFamily: 'Poppins',
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Las ventas a crédito aparecerán aquí',
          style: TextStyle(fontFamily: 'Poppins',
              fontSize: 14, color: AppColors.textMuted)),
    ]));
  }
}

class _Chip extends StatelessWidget {
  final String label, value, selected;
  final Color color;
  final Function(String) onTap;
  const _Chip(this.label, this.value, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? color : AppColors.cardBorder,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? color : AppColors.textSecondary)),
      ),
    );
  }
}

class _ClienteFiadoCard extends StatelessWidget {
  final _ClienteFiado item;
  final VoidCallback onTap;
  const _ClienteFiadoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tienePendiente = item.totalPendiente > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.colorFiado.withValues(alpha: 0.1),
            child: Text(item.cliente.iniciales,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.colorFiado)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.cliente.nombre,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text('${item.cantidadFiados} fiado${item.cantidadFiados > 1 ? 's' : ''}',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 12, color: AppColors.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.moneda(item.totalPendiente),
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: tienePendiente
                        ? AppColors.colorFiado : AppColors.success)),
            const SizedBox(height: 3),
            Text(tienePendiente ? 'pendiente' : 'al día',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    color: tienePendiente
                        ? AppColors.colorFiado : AppColors.success)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }
}