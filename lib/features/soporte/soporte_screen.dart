import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/soporte_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SoporteScreen extends StatefulWidget {
  const SoporteScreen({super.key});
  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _empresaId;
  bool _loadingEmpresa = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargarEmpresaId();
  }

  Future<void> _cargarEmpresaId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _empresaId = prefs.getString('empresa_id');
        _loadingEmpresa = false;
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text('Soporte', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
      bottom: TabBar(
        controller: _tab,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        tabs: const [
          Tab(icon: Icon(Icons.campaign_outlined, size: 20), text: 'Avisos'),
          Tab(icon: Icon(Icons.headset_mic_outlined, size: 20), text: 'Soporte'),
        ],
      ),
    ),
    body: _loadingEmpresa
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : TabBarView(
            controller: _tab,
            children: [
              _AvisosTab(),
              _SoporteTab(empresaId: _empresaId),
            ],
          ),
  );
}

// ══════════════════════════════════════════════════════════════
// TAB AVISOS
// ══════════════════════════════════════════════════════════════
class _AvisosTab extends StatefulWidget {
  @override
  State<_AvisosTab> createState() => _AvisosTabState();
}

class _AvisosTabState extends State<_AvisosTab> {
  List<Map<String, dynamic>> _avisos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SoporteService.getAvisos();
      if (mounted) setState(() { _avisos = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _avisos.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _bannerFijo();
          final a = _avisos[i - 1];
          return _AvisoCard(aviso: a);
        },
      ),
    );
  }

  Widget _bannerFijo() => Column(children: [
    // Banner soporte
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.85), AppColors.primary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estamos aquí para ayudarte', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text('Consulta los avisos y contáctanos en la pestaña Soporte.', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ])),
      ]),
    ),
    // Banner cross-promo FinanPro
    GestureDetector(
      onTap: () async {
        final url = Uri.parse('https://play.google.com/store/apps/details?id=com.finanpro.app');
        try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {}
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Manejas préstamos o créditos?', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('Prueba FinanPro — gestiona tus préstamos fácilmente. Disponible en Google Play.', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
        ]),
      ),
    ),
  ]);
}

class _AvisoCard extends StatelessWidget {
  final Map<String, dynamic> aviso;
  const _AvisoCard({required this.aviso});

  Color get _color {
    switch (aviso['tipo']?.toString()) {
      case 'warning': return AppColors.warning;
      case 'success': return AppColors.success;
      default: return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (aviso['tipo']?.toString()) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'success': return Icons.check_circle_outline_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _color.withValues(alpha: 0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(_icon, color: _color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(aviso['titulo'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(aviso['mensaje'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
      ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// TAB SOPORTE (chat)
// ══════════════════════════════════════════════════════════════
class _SoporteTab extends StatefulWidget {
  final String? empresaId;
  const _SoporteTab({required this.empresaId});
  @override
  State<_SoporteTab> createState() => _SoporteTabState();
}

class _SoporteTabState extends State<_SoporteTab> {
  List<Map<String, dynamic>> _mensajes = [];
  bool _loading = true;
  bool _enviando = false;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.empresaId != null) _cargar();
    else setState(() => _loading = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SoporteService.getMensajes(widget.empresaId!);
      await SoporteService.marcarLeidosUsuario(widget.empresaId!);
      if (mounted) setState(() { _mensajes = res; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _scrollBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || widget.empresaId == null || _enviando) return;
    _ctrl.clear();
    setState(() => _enviando = true);
    try {
      await SoporteService.enviarMensaje(empresaId: widget.empresaId!, mensaje: texto);
      await _cargar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.empresaId == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.business_outlined, size: 60, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Configura tu empresa primero', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Ve a Mi Empresa y guarda tu información para activar el soporte.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13)),
        ]),
      ));
    }

    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return Column(children: [
      Expanded(
        child: _mensajes.isEmpty
            ? _emptyState()
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _mensajes.length,
                itemBuilder: (_, i) => _MensajeBurbuja(msg: _mensajes[i]),
              ),
      ),
      _buildInput(),
    ]);
  }

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.headset_mic_outlined, size: 60, color: AppColors.textMuted.withValues(alpha: 0.5)),
    const SizedBox(height: 16),
    Text('¿Tienes alguna duda?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    Text('Escríbenos y te ayudamos lo antes posible.',
        style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13)),
  ]));

  Widget _buildInput() {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final pad = keyboard > 0 ? 12.0 : bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, pad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje…',
                hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _enviar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: _enviando
                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _MensajeBurbuja extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _MensajeBurbuja({required this.msg});

  bool get _esAdmin => msg['es_admin'] == true;

  @override
  Widget build(BuildContext context) {
    final hora = _formatHora(msg['created_at']?.toString());
    return Align(
      alignment: _esAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(crossAxisAlignment: _esAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
          if (_esAdmin) ...[
            Row(children: [
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 6),
              Text('Soporte', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
            const SizedBox(height: 4),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _esAdmin ? AppColors.surface : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_esAdmin ? 4 : 16),
                bottomRight: Radius.circular(_esAdmin ? 16 : 4),
              ),
              border: _esAdmin ? Border.all(color: AppColors.cardBorder) : null,
            ),
            child: Text(
              msg['mensaje'] ?? '',
              style: GoogleFonts.poppins(fontSize: 14, color: _esAdmin ? AppColors.textPrimary : Colors.white),
            ),
          ),
          const SizedBox(height: 2),
          Text(hora, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
