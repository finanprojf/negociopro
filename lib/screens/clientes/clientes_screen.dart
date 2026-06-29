import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import 'cliente_form_screen.dart';
import 'cliente_detalle_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cliente_service.dart';
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _searchCtrl = TextEditingController();
  String _filtro = 'todos';
  List<ClienteModel> _clientes = [];
  List<ClienteModel> _filtrados = [];
  bool _loading = true;

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
      final clientes = await ClienteService.getClientes();
      if (mounted) setState(() {
        _clientes = clientes;
        _aplicarFiltros();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _aplicarFiltros() {
    var lista = List<ClienteModel>.from(_clientes);
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((c) =>
          c.nombre.toLowerCase().contains(q) ||
          (c.telefono ?? '').contains(q)).toList();
    }
    if (_filtro == 'con_deuda') lista = lista.where((c) => c.tieneDeuda).toList();
    if (_filtro == 'con_puntos') lista = lista.where((c) => c.tienePuntos).toList();
    _filtrados = lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          _buildBuscadorFiltros(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtrados.isEmpty ? _buildEmpty() : _buildLista(),
          ),
        ],
      ),
      floatingActionButton:FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const ClienteFormScreen()));
          if (ok == true) _cargar();
        },
        backgroundColor: AppColors.primary,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            Text('Cliente', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildBuscadorFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(_aplicarFiltros),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o teléfono...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip('Todos', 'todos', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); })),
                const SizedBox(width: 8),
                _Chip('Con deuda', 'con_deuda', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }),
                    color: AppColors.danger),
                const SizedBox(width: 8),
                _Chip('Con puntos', 'con_puntos', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }),
                    color: AppColors.colorFidelizacion),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ClienteTile(
        cliente: _filtrados[i],
       onTap: () async {
            final ok = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: _filtrados[i])));
            if (ok == true) _cargar();
          },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        const Text('Sin clientes', style: TextStyle(fontFamily: 'Poppins',
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Agrega tu primer cliente', style: TextStyle(
            fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;
  final Color color;
  const _Chip(this.label, this.value, this.selected, this.onTap,
      {this.color = AppColors.primary});

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
          border: Border.all(color: sel ? color : AppColors.cardBorder,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? color : AppColors.textSecondary)),
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  final ClienteModel cliente;
  final VoidCallback onTap;
  const _ClienteTile({required this.cliente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Avatar con iniciales
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
              child: Text(cliente.iniciales,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.colorClientes)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cliente.nombre, style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  if (cliente.telefono != null)
                    Text(cliente.telefono!, style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (cliente.tieneDeuda)
                  _Badge(AppFormatters.moneda(cliente.saldoFiado!),
                      AppColors.danger, AppColors.dangerSurface),
                if (cliente.tienePuntos) ...[
                  const SizedBox(height: 4),
                  _Badge('${cliente.puntosFidelidad} pts',
                      AppColors.colorFidelizacion,
                      AppColors.colorFidelizacion.withValues(alpha: 0.1)),
                ],
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String texto;
  final Color color;
  final Color bg;
  const _Badge(this.texto, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontFamily: 'Poppins',
          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}