import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/soporte_service.dart';

class SoporteAdminScreen extends StatefulWidget {
  const SoporteAdminScreen({super.key});
  @override
  State<SoporteAdminScreen> createState() => _SoporteAdminScreenState();
}

class _SoporteAdminScreenState extends State<SoporteAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text('Soporte Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
      bottom: TabBar(
        controller: _tab,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        tabs: const [
          Tab(icon: Icon(Icons.forum_outlined, size: 20), text: 'Chats'),
          Tab(icon: Icon(Icons.campaign_outlined, size: 20), text: 'Avisos'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: [
      _ChatsTab(),
      _AvisosAdminTab(),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// ADMIN — Lista de conversaciones
// ══════════════════════════════════════════════════════════════
class _ChatsTab extends StatefulWidget {
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  List<Map<String, dynamic>> _convs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SoporteService.adminGetConversaciones();
      if (mounted) setState(() { _convs = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_convs.isEmpty) return Center(child: Text('Sin mensajes de soporte', style: GoogleFonts.poppins(color: AppColors.textMuted)));
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _convs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = _convs[i];
          final noLeidos = (c['no_leidos'] as num? ?? 0).toInt();
          return GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => _ChatAdminDetail(
                  empresaId: c['empresa_id']?.toString() ?? '',
                  empresaNombre: c['empresa_nombre']?.toString() ?? 'Sin nombre',
                  usuarioCorreo: c['usuario_correo']?.toString() ?? '',
                ),
              ));
              _cargar();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: noLeidos > 0 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['empresa_nombre']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  Text(c['usuario_correo']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(c['ultimo_mensaje']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (noLeidos > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$noLeidos', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ADMIN — Chat detalle
// ══════════════════════════════════════════════════════════════
class _ChatAdminDetail extends StatefulWidget {
  final String empresaId;
  final String empresaNombre;
  final String usuarioCorreo;
  const _ChatAdminDetail({required this.empresaId, required this.empresaNombre, required this.usuarioCorreo});
  @override
  State<_ChatAdminDetail> createState() => _ChatAdminDetailState();
}

class _ChatAdminDetailState extends State<_ChatAdminDetail> {
  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  bool _enviando = false;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() { super.initState(); _cargar(); }
  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      await SoporteService.adminMarcarLeidos(widget.empresaId);
      final res = await SoporteService.adminGetConversacion(widget.empresaId);
      if (mounted) setState(() { _msgs = res; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _responder() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    _ctrl.clear();
    setState(() => _enviando = true);
    try {
      await SoporteService.adminResponder(widget.empresaId, texto);
      await _cargar();
    } catch (_) {} finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _eliminarConversacion() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Eliminar conversación', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text('¿Eliminar todos los mensajes de ${widget.empresaNombre}?', style: GoogleFonts.poppins()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ));
    if (ok != true) return;
    await SoporteService.adminEliminarConversacion(widget.empresaId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.empresaNombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(widget.usuarioCorreo, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
      ]),
      actions: [
        IconButton(
          iconSize: 22,
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: _eliminarConversacion,
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(children: [
            Expanded(
              child: _msgs.isEmpty
                  ? Center(child: Text('Sin mensajes', style: GoogleFonts.poppins(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _AdminBurbuja(msg: _msgs[i]),
                    ),
            ),
            _buildInput(),
          ]),
  );

  Widget _buildInput() {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final pad = keyboard > 0 ? 12.0 : bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, pad),
      decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.cardBorder))),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.cardBorder)),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Responder a ${widget.empresaNombre}…',
                hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _responder,
          child: Container(
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

class _AdminBurbuja extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _AdminBurbuja({required this.msg});
  bool get _esAdmin => msg['es_admin'] == true;

  @override
  Widget build(BuildContext context) {
    final hora = _formatHora(msg['created_at']?.toString());
    return Align(
      alignment: _esAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(crossAxisAlignment: _esAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _esAdmin ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_esAdmin ? 16 : 4),
                bottomRight: Radius.circular(_esAdmin ? 4 : 16),
              ),
              border: _esAdmin ? null : Border.all(color: AppColors.cardBorder),
            ),
            child: Text(msg['mensaje'] ?? '', style: GoogleFonts.poppins(fontSize: 14, color: _esAdmin ? Colors.white : AppColors.textPrimary)),
          ),
          const SizedBox(height: 2),
          Text('${_esAdmin ? 'Admin · ' : ''}$hora', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}

// ══════════════════════════════════════════════════════════════
// ADMIN — Avisos
// ══════════════════════════════════════════════════════════════
class _AvisosAdminTab extends StatefulWidget {
  @override
  State<_AvisosAdminTab> createState() => _AvisosAdminTabState();
}

class _AvisosAdminTabState extends State<_AvisosAdminTab> {
  List<Map<String, dynamic>> _avisos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SoporteService.adminGetAvisos();
      if (mounted) setState(() { _avisos = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _mostrarFormAviso() {
    final tituloCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String tipo = 'info';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nuevo aviso', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: tituloCtrl,
                decoration: InputDecoration(labelText: 'Título', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('Tipo: ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                for (final t in ['info', 'warning', 'success'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t, style: GoogleFonts.poppins(fontSize: 12)),
                      selected: tipo == t,
                      onSelected: (_) => setS(() => tipo = t),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final t = tituloCtrl.text.trim();
                    final m = msgCtrl.text.trim();
                    if (t.isEmpty || m.isEmpty) return;
                    Navigator.pop(ctx);
                    await SoporteService.adminPublicarAviso(titulo: t, mensaje: m, tipo: tipo);
                    _cargar();
                  },
                  child: Text('Publicar', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nuevo aviso', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: _mostrarFormAviso,
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _avisos.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text('Sin avisos publicados', style: GoogleFonts.poppins(color: AppColors.textMuted))),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _avisos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = _avisos[i];
                  final activo = a['activo'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: activo ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cardBorder),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (activo ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(activo ? 'Activo' : 'Inactivo',
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: activo ? AppColors.success : AppColors.textMuted)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                            child: Text(a['tipo']?.toString() ?? 'info', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(a['titulo']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(a['mensaje']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                      ])),
                      if (activo) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 22,
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.visibility_off_outlined, color: AppColors.textMuted),
                          onPressed: () async {
                            await SoporteService.adminDesactivarAviso(a['id']?.toString() ?? '');
                            _cargar();
                          },
                        ),
                      ],
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
