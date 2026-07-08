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

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _empresas = [];
  bool _loading = true;
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
     final res = await SupabaseService.client
          .from('empresas')
          .select('id, nombre, telefono, whatsapp, plan_activo, suscripcion_vence, created_at, usuarios(correo)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _empresas = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Error admin: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtradas {
    if (_filtro == 'todas') return _empresas;
    if (_filtro == 'activas') {
      return _empresas.where((e) {
        if (e['suscripcion_vence'] == null) return false;
        return DateTime.parse(e['suscripcion_vence']).isAfter(DateTime.now());
      }).toList();
    }
    if (_filtro == 'vencidas') {
      return _empresas.where((e) {
        if (e['suscripcion_vence'] == null) return true;
        return DateTime.parse(e['suscripcion_vence']).isBefore(DateTime.now());
      }).toList();
    }
    if (_filtro == 'trial') {
      return _empresas.where((e) => e['plan_activo'] == 'trial').toList();
    }
    return _empresas;
  }

  int get _activas => _empresas.where((e) {
    if (e['suscripcion_vence'] == null) return false;
    return DateTime.parse(e['suscripcion_vence']).isAfter(DateTime.now());
  }).length;

  int get _vencidas => _empresas.where((e) {
    if (e['suscripcion_vence'] == null) return true;
    return DateTime.parse(e['suscripcion_vence']).isBefore(DateTime.now());
  }).length;

  Future<void> _abrirWA(String numero, String mensaje) async {
    final num = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$num?text=${Uri.encodeComponent(mensaje)}';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('❌ Error WA: $e');
    }
  }

  String _planLabel(int dias) {
    if (dias == 30) return '1 mes — \$6.99';
    if (dias == 90) return '3 meses — \$17.99';
    if (dias == 180) return '6 meses — \$29.99';
    if (dias == 365) return '1 año — \$49.99';
    return '$dias días';
  }

  String _planPrecio(int dias) {
    if (dias == 30) return '\$6.99';
    if (dias == 90) return '\$17.99';
    if (dias == 180) return '\$29.99';
    if (dias == 365) return '\$49.99';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              _buildResumen(),
              _buildFiltros(),
              Expanded(child: _buildLista()),
            ]),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _StatAdmin('${_empresas.length}', 'Total', Colors.white),
        _Div(),
        _StatAdmin('$_activas', 'Activas', Colors.greenAccent),
        _Div(),
        _StatAdmin('$_vencidas', 'Vencidas', Colors.redAccent),
        _Div(),
        _StatAdmin(
            '${_empresas.where((e) => e['plan_activo'] == 'trial').length}',
            'Trial', Colors.amberAccent),
      ]),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildChip('Todas', 'todas', AppColors.primary),
          const SizedBox(width: 8),
          _buildChip('Activas', 'activas', AppColors.success),
          const SizedBox(width: 8),
          _buildChip('Vencidas', 'vencidas', AppColors.danger),
          const SizedBox(width: 8),
          _buildChip('Trial', 'trial', AppColors.warning),
        ]),
      ),
    );
  }

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
          border: Border.all(color: sel ? color : AppColors.cardBorder,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? color : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildLista() {
    if (_filtradas.isEmpty) {
      return Center(child: Text('Sin empresas',
          style: GoogleFonts.poppins(color: AppColors.textMuted)));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _filtradas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final e = _filtradas[i];
          final venceStr = e['suscripcion_vence'];
          DateTime? vence = venceStr != null ? DateTime.parse(venceStr) : null;
          final dias = vence?.difference(DateTime.now()).inDays;
          final activa = dias != null && dias >= 0;
          final telefono = e['whatsapp'] ?? e['telefono'] ?? '';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Expanded(child: Text(e['nombre'] ?? 'Sin nombre',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activa ? AppColors.successSurface : AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(activa ? '✓ Activa' : '✕ Vencida',
                      style: GoogleFonts.poppins(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: activa ? AppColors.success : AppColors.danger)),
                ),
              ]),
              const SizedBox(height: 8),

              // Info
           if (e['usuarios'] != null && (e['usuarios'] as List).isNotEmpty)
                _InfoRow(Icons.email_outlined, 
                    (e['usuarios'] as List).first['correo'] ?? ''),
              if (telefono.isNotEmpty)
                _InfoRow(Icons.phone_outlined, telefono),
              _InfoRow(Icons.calendar_today_rounded,
                vence != null
                    ? 'Vence: ${AppFormatters.fecha(vence)} ${dias != null && dias >= 0 ? '($dias días)' : '(vencida)'}'
                    : 'Sin suscripción',
                color: dias != null && dias <= 7 && dias >= 0
                    ? AppColors.warning : null,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: 12),

              // Planes
              Text('Activar plan:', style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _PlanBtn('1 mes', () => _activarPlan(e, 30, telefono)),
                const SizedBox(width: 6),
                _PlanBtn('3 meses', () => _activarPlan(e, 90, telefono)),
                const SizedBox(width: 6),
                _PlanBtn('6 meses', () => _activarPlan(e, 180, telefono)),
                const SizedBox(width: 6),
                _PlanBtn('1 año', () => _activarPlan(e, 365, telefono),
                    color: AppColors.success),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _activarPlan(Map<String, dynamic> empresa, int dias, String telefono) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Activar plan', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Empresa: ${empresa['nombre']}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Plan: ${_planLabel(dias)}',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(
                color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Activar', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final venceActual = empresa['suscripcion_vence'];
      DateTime base = DateTime.now();
      if (venceActual != null) {
        final vence = DateTime.parse(venceActual);
        base = vence.isAfter(DateTime.now()) ? vence : DateTime.now();
      }
      final nuevaFecha = base.add(Duration(days: dias));
      final nuevaFechaStr = AppFormatters.fecha(nuevaFecha);

      await SupabaseService.client.from('empresas').update({
        'suscripcion_vence': nuevaFecha.toIso8601String(),
        'plan_activo': 'activo',
      }).eq('id', empresa['id']);

      _cargar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Plan activado! Vence: $nuevaFechaStr'),
          backgroundColor: AppColors.success,
        ));

        // Ofrecer enviar recibo por WhatsApp
        if (telefono.isNotEmpty) {
          _ofrecerEnviarRecibo(empresa, dias, nuevaFechaStr, telefono);
        }
      }
    } catch (e) {
      print('❌ Error activar: $e');
    }
  }

  void _ofrecerEnviarRecibo(Map<String, dynamic> empresa, int dias,
      String fechaVence, String telefono) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Enviar recibo?', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700)),
        content: Text('¿Deseas enviar el recibo del plan a ${empresa['nombre']}?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No', style: GoogleFonts.poppins(
                color: AppColors.textMuted))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final recibo = '''
✅ *Recibo de Suscripción — NegocioPro*

🏪 Negocio: ${empresa['nombre']}
📦 Plan: ${_planLabel(dias)}
💵 Monto: ${_planPrecio(dias)}
📅 Válido hasta: $fechaVence

Gracias por confiar en NegocioPro 🙌
_Por FinanPro Solutions_
''';
              _abrirWA(telefono, recibo);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('Enviar por WhatsApp',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }
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
      Expanded(child: Text(texto, style: GoogleFonts.poppins(
          fontSize: 12,
          color: color ?? AppColors.textSecondary))),
    ]),
  );
}

class _PlanBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _PlanBtn(this.label, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: (color ?? AppColors.primary).withValues(alpha: 0.4)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: color ?? AppColors.primary)),
      ),
    ),
  );
}

class _StatAdmin extends StatelessWidget {
  final String valor, label;
  final Color color;
  const _StatAdmin(this.valor, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(valor, style: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: GoogleFonts.poppins(
          fontSize: 11, color: Colors.white70)),
    ]),
  );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 36, color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}