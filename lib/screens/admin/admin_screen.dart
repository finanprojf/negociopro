import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../services/supabase_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _Periodo {
  final int dias;
  final String label;
  const _Periodo({required this.dias, required this.label});
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _empresas = [];
  bool _loading = true;
  String _filtro = 'todas';

  static const _preciosBasico = {30: 7.99, 90: 19.99, 180: 37.99, 365: 69.99};
  static const _preciosPro   = {30: 14.99, 90: 37.99, 180: 71.99, 365: 129.99};
  static const _periodos = [
    _Periodo(dias: 30,  label: '1 mes'),
    _Periodo(dias: 90,  label: '3 meses'),
    _Periodo(dias: 180, label: '6 meses'),
    _Periodo(dias: 365, label: '1 año'),
  ];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client
          .from('empresas')
          .select('id, nombre, telefono, whatsapp, pais, plan_activo, suscripcion_vence, created_at, usuarios(id, nombre, correo), productos(count)')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _empresas = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filtradas {
    switch (_filtro) {
      case 'activas':  return _empresas.where((e) { if (e['suscripcion_vence'] == null) return false; return DateTime.parse(e['suscripcion_vence']).isAfter(DateTime.now()); }).toList();
      case 'vencidas': return _empresas.where((e) { if (e['suscripcion_vence'] == null) return true;  return DateTime.parse(e['suscripcion_vence']).isBefore(DateTime.now()); }).toList();
      case 'trial':    return _empresas.where((e) => e['plan_activo'] == 'trial').toList();
      case 'basico':   return _empresas.where((e) => e['plan_activo'] == 'basico').toList();
      case 'pro':      return _empresas.where((e) => e['plan_activo'] == 'pro' || e['plan_activo'] == 'activo').toList();
      default:         return _empresas;
    }
  }

  int get _activas  => _empresas.where((e) { if (e['suscripcion_vence'] == null) return false; return DateTime.parse(e['suscripcion_vence']).isAfter(DateTime.now()); }).length;
  int get _vencidas => _empresas.where((e) { if (e['suscripcion_vence'] == null) return true;  return DateTime.parse(e['suscripcion_vence']).isBefore(DateTime.now()); }).length;
  int get _enTrial  => _empresas.where((e) => e['plan_activo'] == 'trial').length;
  int get _enBasico => _empresas.where((e) => e['plan_activo'] == 'basico').length;
  int get _enPro    => _empresas.where((e) => e['plan_activo'] == 'pro' || e['plan_activo'] == 'activo').length;

  Future<void> _abrirWA(String numero, String mensaje) async {
    final num = numero.replaceAll(RegExp(r'[^0-9]'), '');
    try { await launchUrl(Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(mensaje)}'), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  String _etiquetaPlan(dynamic plan) {
    switch (plan?.toString()) {
      case 'pro': case 'activo': return 'Pro';
      case 'basico': return 'Básico';
      case 'trial':  return 'Trial';
      default:       return 'Sin plan';
    }
  }

  Color _colorPlan(dynamic plan) {
    switch (plan?.toString()) {
      case 'pro': case 'activo': return const Color(0xFF7C3AED);
      case 'basico': return AppColors.primary;
      case 'trial':  return AppColors.warning;
      default:       return AppColors.textMuted;
    }
  }

  String _labelPeriodo(int dias) {
    if (dias == 30)  return '1 mes';
    if (dias == 90)  return '3 meses';
    if (dias == 180) return '6 meses';
    if (dias == 365) return '1 año';
    return '$dias días';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Panel Admin'),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar)],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(children: [_buildResumen(), _buildFiltros(), Expanded(child: _buildLista())]),
  );

  Widget _buildResumen() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Row(children: [
        _StatAdmin('${_empresas.length}', 'Total',   Colors.white),
        _Div(),
        _StatAdmin('$_activas',           'Activas', Colors.greenAccent),
        _Div(),
        _StatAdmin('$_vencidas',          'Vencidas', Colors.redAccent),
      ]),
      const SizedBox(height: 12),
      Container(height: 1, color: Colors.white24),
      const SizedBox(height: 12),
      Row(children: [
        _StatAdmin('$_enTrial',  'Trial',  Colors.amberAccent),
        _Div(),
        _StatAdmin('$_enBasico', 'Básico', Colors.lightBlueAccent),
        _Div(),
        _StatAdmin('$_enPro',    'Pro',    const Color(0xFFD8B4FE)),
      ]),
    ]),
  );

  Widget _buildFiltros() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _buildChip('Todas',   'todas',   AppColors.primary),
        const SizedBox(width: 8),
        _buildChip('Activas', 'activas', AppColors.success),
        const SizedBox(width: 8),
        _buildChip('Vencidas','vencidas',AppColors.danger),
        const SizedBox(width: 8),
        _buildChip('Trial',   'trial',   AppColors.warning),
        const SizedBox(width: 8),
        _buildChip('Básico',  'basico',  AppColors.primary),
        const SizedBox(width: 8),
        _buildChip('Pro',     'pro',     const Color(0xFF7C3AED)),
      ]),
    ),
  );

  Widget _buildChip(String label, String value, Color color) {
    final sel = _filtro == value;
    return GestureDetector(
      onTap: () => setState(() => _filtro = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : AppColors.cardBorder, width: sel ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? color : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildLista() {
    if (_filtradas.isEmpty) return Center(child: Text('Sin empresas', style: GoogleFonts.poppins(color: AppColors.textMuted)));
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _filtradas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EmpresaCard(
          empresa: _filtradas[i],
          etiquetaPlan: _etiquetaPlan,
          colorPlan: _colorPlan,
          labelPeriodo: _labelPeriodo,
          periodos: _periodos,
          preciosBasico: _preciosBasico,
          preciosPro: _preciosPro,
          onActivar: _activarPlan,
          onEditar: _editarUsuario,
          onEliminar: _eliminarUsuario,
        ),
      ),
    );
  }

  Future<void> _activarPlan(Map<String, dynamic> empresa, int dias, String tipoPlan, String telefono) async {
    final precios = tipoPlan == 'pro' ? _preciosPro : _preciosBasico;
    final precio = precios[dias] ?? 0.0;
    final label = '${tipoPlan == 'pro' ? 'Pro' : 'Básico'} — ${_labelPeriodo(dias)}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Activar plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(empresa['nombre'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Plan: $label', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          Text('Precio: \$$precio', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Activar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final venceActual = empresa['suscripcion_vence'];
      DateTime base = DateTime.now();
      if (venceActual != null) {
        final vence = DateTime.parse(venceActual);
        if (vence.isAfter(DateTime.now())) base = vence;
      }
      final nuevaFecha = base.add(Duration(days: dias));
      final nuevaFechaStr = AppFormatters.fecha(nuevaFecha);

      await SupabaseService.client.from('empresas').update({
        'suscripcion_vence': nuevaFecha.toUtc().toIso8601String(),
        'plan_activo': tipoPlan,
      }).eq('id', empresa['id']);

      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Plan activado! Vence: $nuevaFechaStr'), backgroundColor: AppColors.success));
        if (telefono.isNotEmpty) _ofrecerEnviarRecibo(empresa, dias, tipoPlan, precio, nuevaFechaStr, telefono);
      }
    } catch (_) {}
  }

  void _ofrecerEnviarRecibo(Map<String, dynamic> empresa, int dias, String tipoPlan, double precio, String fechaVence, String telefono) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Enviar recibo?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Enviar recibo a ${empresa['nombre']}?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('No', style: GoogleFonts.poppins(color: AppColors.textMuted))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final nombrePlan = tipoPlan == 'pro' ? 'Pro' : 'Básico';
              _abrirWA(telefono, '''
✅ *Recibo de Suscripción — NegocioPro*

🏪 Negocio: ${empresa['nombre']}
📦 Plan: $nombrePlan — ${_labelPeriodo(dias)}
💵 Monto: \$$precio
📅 Válido hasta: $fechaVence

Gracias por confiar en NegocioPro 🙌
_Por FinanPro Solutions_
''');
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('Enviar por WhatsApp', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }

  Future<void> _editarUsuario(Map<String, dynamic> empresa) async {
    final usuarios = empresa['usuarios'] as List? ?? [];
    final correoActual = usuarios.isNotEmpty ? (usuarios.first['correo'] ?? '') : '';
    final usuarioId = usuarios.isNotEmpty ? usuarios.first['id'] as String? : null;
    if (usuarioId == null || usuarioId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el ID del usuario'), backgroundColor: AppColors.danger));
      return;
    }
    final correoCtrl = TextEditingController(text: correoActual);
    final passCtrl = TextEditingController();
    bool obscure = true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar usuario', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(empresa['nombre'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(controller: correoCtrl, keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Correo electrónico', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña (opcional)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setS(() => obscure = !obscure)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                )),
            const SizedBox(height: 8),
            Text('Deja la contraseña vacía si no quieres cambiarla.', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: GoogleFonts.poppins(color: AppColors.textMuted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final nuevoCorreo = correoCtrl.text.trim();
    final nuevaPass = passCtrl.text.trim();
    if (nuevoCorreo.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El correo no puede estar vacío'), backgroundColor: AppColors.warning));
      return;
    }
    try {
      final body = <String, dynamic>{'accion': 'actualizar', 'usuario_id': usuarioId, 'nuevo_correo': nuevoCorreo};
      if (nuevaPass.isNotEmpty) body['nueva_contrasena'] = nuevaPass;
      final response = await SupabaseService.client.functions.invoke('admin-user-manager', body: body);
      if (response.status == 200) {
        _cargar();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado correctamente'), backgroundColor: AppColors.success));
      } else {
        final data = response.data;
        final msg = data is Map ? (data['error'] ?? 'Error desconocido') : 'Error';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> empresa) async {
    final usuarios = empresa['usuarios'] as List? ?? [];
    final usuarioId = usuarios.isNotEmpty ? usuarios.first['id'] as String? : null;
    if (usuarioId == null || usuarioId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el ID del usuario'), backgroundColor: AppColors.danger));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('⚠️ Eliminar usuario', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.danger)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Estás seguro?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Empresa: ${empresa['nombre']}', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.dangerSurface, borderRadius: BorderRadius.circular(8)),
            child: Text('Esta acción es irreversible. Se eliminará el usuario y todos sus datos.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final response = await SupabaseService.client.functions.invoke('admin-user-manager', body: {'accion': 'eliminar', 'usuario_id': usuarioId});
      if (response.status == 200) {
        _cargar();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado correctamente'), backgroundColor: AppColors.success));
      } else {
        final data = response.data;
        final msg = data is Map ? (data['error'] ?? 'Error desconocido') : 'Error';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// Tarjeta expandible por empresa
// ══════════════════════════════════════════════════════════════════
class _EmpresaCard extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final String Function(dynamic) etiquetaPlan;
  final Color Function(dynamic) colorPlan;
  final String Function(int) labelPeriodo;
  final List<_Periodo> periodos;
  final Map<int, double> preciosBasico;
  final Map<int, double> preciosPro;
  final Future<void> Function(Map<String, dynamic>, int, String, String) onActivar;
  final Future<void> Function(Map<String, dynamic>) onEditar;
  final Future<void> Function(Map<String, dynamic>) onEliminar;
  const _EmpresaCard({required this.empresa, required this.etiquetaPlan, required this.colorPlan, required this.labelPeriodo, required this.periodos, required this.preciosBasico, required this.preciosPro, required this.onActivar, required this.onEditar, required this.onEliminar});

  @override
  State<_EmpresaCard> createState() => _EmpresaCardState();
}

class _EmpresaCardState extends State<_EmpresaCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.empresa;
    final venceStr = e['suscripcion_vence'];
    final DateTime? vence = venceStr != null ? DateTime.parse(venceStr) : null;
    final dias = vence?.difference(DateTime.now()).inDays;
    final activa = dias != null && dias >= 0;
    final telefono = e['whatsapp'] ?? e['telefono'] ?? '';
    final planColor = widget.colorPlan(e['plan_activo']);

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e['nombre'] ?? 'Sin nombre', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: planColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: planColor.withValues(alpha: 0.4), width: 1)),
                  child: Text(activa ? '✓ ${widget.etiquetaPlan(e['plan_activo'])}' : '✕ Vencida',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: activa ? planColor : AppColors.danger)),
                ),
                const SizedBox(width: 6),
                Icon(_expandido ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
              ]),
              const SizedBox(height: 6),
              // Nombre del usuario propietario
              if (e['usuarios'] != null && (e['usuarios'] as List).isNotEmpty) ...[
                _InfoRow(Icons.person_outline_rounded, (e['usuarios'] as List).first['nombre'] ?? 'Sin nombre'),
                _InfoRow(Icons.email_outlined, (e['usuarios'] as List).first['correo'] ?? ''),
              ],
              if (telefono.isNotEmpty) _InfoRow(Icons.phone_outlined, telefono),
              if ((e['pais'] ?? '').toString().isNotEmpty)
                _InfoRow(Icons.public_rounded, e['pais'].toString()),
              // Conteo de productos en inventario
              Builder(builder: (_) {
                final prods = e['productos'];
                if (prods == null) return const SizedBox.shrink();
                final count = prods is List ? prods.length : (prods is Map ? (prods['count'] ?? 0) : 0);
                return _InfoRow(Icons.inventory_2_outlined, '$count producto${count == 1 ? '' : 's'} en inventario',
                    color: count == 0 ? AppColors.textMuted : null);
              }),
              _InfoRow(Icons.calendar_today_rounded,
                vence != null
                    ? 'Vence: ${AppFormatters.fecha(vence)}${dias != null && dias >= 0 ? ' ($dias días)' : ' (vencida)'}'
                    : 'Sin suscripción',
                color: dias != null && dias <= 7 && dias >= 0 ? AppColors.warning : null,
              ),
            ]),
          ),
        ),
        if (_expandido) ...[
          const Divider(height: 1, color: AppColors.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _PlanSection(titulo: '📦 Básico', color: AppColors.primary, periodos: widget.periodos, precios: widget.preciosBasico, onTap: (d) => widget.onActivar(e, d, 'basico', telefono)),
              const SizedBox(height: 12),
              _PlanSection(titulo: '⭐ Pro', color: const Color(0xFF7C3AED), periodos: widget.periodos, precios: widget.preciosPro, onTap: (d) => widget.onActivar(e, d, 'pro', telefono)),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: 10),
              // ── Botones de contacto ──────────────────────────
              if (telefono.isNotEmpty || ((e['usuarios'] as List?)?.isNotEmpty ?? false)) ...[
                Row(children: [
                  if (telefono.isNotEmpty) Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final num = telefono.replaceAll(RegExp(r'[^0-9]'), '');
                      await launchUrl(Uri.parse('https://wa.me/$num'),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat_rounded, size: 15, color: Color(0xFF25D366)),
                    label: Text('WhatsApp', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF25D366))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  )),
                  if (telefono.isNotEmpty && ((e['usuarios'] as List?)?.isNotEmpty ?? false)) const SizedBox(width: 8),
                  if ((e['usuarios'] as List?)?.isNotEmpty ?? false) Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final correo = (e['usuarios'] as List).first['correo'] ?? '';
                      if (correo.isEmpty) return;
                      await launchUrl(Uri.parse('mailto:$correo'),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.email_outlined, size: 15, color: Color(0xFF4A90D9)),
                    label: Text('Correo', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A90D9))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF4A90D9)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  )),
                ]),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => widget.onEditar(e),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text('Editar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => widget.onEliminar(e),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: Text('Eliminar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                )),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _PlanSection extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<_Periodo> periodos;
  final Map<int, double> precios;
  final void Function(int) onTap;
  const _PlanSection({required this.titulo, required this.color, required this.periodos, required this.precios, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(titulo, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 6),
    Row(children: periodos.map((p) {
      final precio = precios[p.dias];
      return Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: GestureDetector(
          onTap: () => onTap(p.dias),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.35))),
            child: Column(children: [
              Text(p.label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              if (precio != null) Text('\$$precio', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9, color: color.withValues(alpha: 0.8))),
            ]),
          ),
        ),
      ));
    }).toList()),
  ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color? color;
  const _InfoRow(this.icon, this.texto, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: color ?? AppColors.textMuted),
      const SizedBox(width: 6),
      Expanded(child: Text(texto, style: GoogleFonts.poppins(fontSize: 12, color: color ?? AppColors.textSecondary))),
    ]),
  );
}

class _StatAdmin extends StatelessWidget {
  final String valor, label;
  final Color color;
  const _StatAdmin(this.valor, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(valor, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
  ]));
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8));
}
