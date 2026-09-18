import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';

class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _completados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      final db = await LocalDatabase.database;
      final rows = await db.query(
        'recordatorios',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
        orderBy: 'fecha ASC, hora ASC',
      );
      if (mounted) {
        setState(() {
          _pendientes = rows.where((r) => r['completado'] == 0).toList();
          _completados = rows.where((r) => r['completado'] == 1).toList();
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recordatorios',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _abrirFormulario,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: Text('Nuevo', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(child: Text('Pendientes (${_pendientes.length})',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
            Tab(child: Text('Completados',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildLista(_pendientes, completados: false),
                _buildLista(_completados, completados: true),
              ],
            ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> items,
      {required bool completados}) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(completados
              ? Icons.check_circle_outline_rounded
              : Icons.notifications_none_rounded,
              size: 64, color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(completados
              ? 'Sin recordatorios completados'
              : 'No tienes recordatorios pendientes',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: AppColors.textMuted)),
          if (!completados) ...[
            const SizedBox(height: 8),
            Text('Toca + para crear uno',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textMuted)),
          ],
        ]),
      );
    }

    // Agrupar por fecha
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final r in items) {
      final fecha = r['fecha'] as String;
      grupos.putIfAbsent(fecha, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: grupos.entries.map((entry) {
        final fecha = _formatearFecha(entry.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorFecha(entry.key).$2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(fecha,
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _colorFecha(entry.key).$1)),
                ),
              ]),
            ),
            ...entry.value.map((r) => _RecordatorioCard(
              recordatorio: r,
              onToggle: () => _toggleCompletado(r),
              onEdit: () => _abrirFormulario(recordatorio: r),
              onDelete: () => _eliminar(r),
            )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  (Color, Color) _colorFecha(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final diff = fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      if (diff < 0) return (AppColors.danger, AppColors.danger.withValues(alpha: 0.1));
      if (diff == 0) return (AppColors.primary, AppColors.primary.withValues(alpha: 0.1));
      if (diff == 1) return (AppColors.warning, AppColors.warning.withValues(alpha: 0.1));
      return (AppColors.textSecondary, AppColors.surface);
    } catch (_) {
      return (AppColors.textSecondary, AppColors.surface);
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final diff = fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      if (diff < -1) return 'Atrasado — ${_nombreDia(fecha)}';
      if (diff == -1) return 'Ayer (atrasado)';
      if (diff == 0) return '📅 Hoy';
      if (diff == 1) return '⏰ Mañana';
      return _nombreDia(fecha);
    } catch (_) {
      return fechaStr;
    }
  }

  String _nombreDia(DateTime d) {
    const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }

  Future<void> _toggleCompletado(Map<String, dynamic> r) async {
    final db = await LocalDatabase.database;
    final nuevoEstado = r['completado'] == 0 ? 1 : 0;
    await db.update('recordatorios', {'completado': nuevoEstado},
        where: 'id = ?', whereArgs: [r['id']]);
    _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar recordatorio',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "${r['titulo']}"?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = await LocalDatabase.database;
    await db.delete('recordatorios', where: 'id = ?', whereArgs: [r['id']]);
    _cargar();
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? recordatorio}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null || !mounted) return;

    // Cargar clientes para el selector
    final db = await LocalDatabase.database;
    final clientes = await db.query('clientes',
        where: 'empresa_id = ? AND activo = 1', whereArgs: [empresaId],
        orderBy: 'nombre ASC');

    if (!mounted) return;

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioRecordatorio(
        empresaId: empresaId,
        clientes: clientes,
        recordatorio: recordatorio,
      ),
    );

    if (resultado == true) _cargar();
  }
}

// ─── Card de recordatorio ─────────────────────────────────────────────────

class _RecordatorioCard extends StatelessWidget {
  final Map<String, dynamic> recordatorio;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordatorioCard({
    required this.recordatorio,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completado = recordatorio['completado'] == 1;
    final clienteNombre = recordatorio['cliente_nombre'] as String?;
    final hora = recordatorio['hora'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completado
              ? AppColors.cardBorder
              : AppColors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: completado ? [] : [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completado
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: completado ? AppColors.success : AppColors.primary,
                width: 1.5,
              ),
            ),
            child: completado
                ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                : const SizedBox.shrink(),
          ),
        ),
        title: Text(recordatorio['titulo'] as String,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: completado ? AppColors.textMuted : AppColors.textPrimary,
                decoration: completado ? TextDecoration.lineThrough : null)),
        subtitle: Row(children: [
          if (clienteNombre != null) ...[
            const Icon(Icons.person_outline_rounded, size: 12,
                color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text(clienteNombre,
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
          ],
          if (hora != null) ...[
            const Icon(Icons.access_time_rounded, size: 12,
                color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text(hora,
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textMuted, size: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
            if (v == 'toggle') onToggle();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'toggle',
                child: Text(completado ? 'Marcar pendiente' : 'Marcar completado',
                    style: GoogleFonts.poppins(fontSize: 13))),
            PopupMenuItem(value: 'edit',
                child: Text('Editar', style: GoogleFonts.poppins(fontSize: 13))),
            PopupMenuItem(value: 'delete',
                child: Text('Eliminar',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.danger))),
          ],
        ),
      ),
    );
  }
}

// ─── Formulario crear/editar ─────────────────────────────────────────────

class _FormularioRecordatorio extends StatefulWidget {
  final String empresaId;
  final List<Map<String, dynamic>> clientes;
  final Map<String, dynamic>? recordatorio;

  const _FormularioRecordatorio({
    required this.empresaId,
    required this.clientes,
    this.recordatorio,
  });

  @override
  State<_FormularioRecordatorio> createState() =>
      _FormularioRecordatorioState();
}

class _FormularioRecordatorioState extends State<_FormularioRecordatorio> {
  final _tituloCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  TimeOfDay? _hora;
  String? _clienteId;
  String? _clienteNombre;
  bool _guardando = false;

  // Sugerencias rápidas de texto
  static const _sugerencias = [
    'Cobrarle a cliente',
    'Llamar a proveedor',
    'Revisar inventario',
    'Pagar factura',
    'Entregar pedido',
    'Hacer inventario',
    'Llamar cliente',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.recordatorio;
    if (r != null) {
      _tituloCtrl.text = r['titulo'] as String;
      _fecha = DateTime.parse(r['fecha'] as String);
      _clienteId = r['cliente_id'] as String?;
      _clienteNombre = r['cliente_nombre'] as String?;
      final horaStr = r['hora'] as String?;
      if (horaStr != null) {
        final parts = horaStr.split(':');
        _hora = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.recordatorio != null;
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(esEdicion ? 'Editar recordatorio' : 'Nuevo recordatorio',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Campo título
        TextField(
          controller: _tituloCtrl,
          autofocus: !esEdicion,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            labelText: '¿Qué tienes que hacer?',
            prefixIcon: const Icon(Icons.edit_note_rounded,
                color: AppColors.textMuted, size: 22),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // Sugerencias rápidas
        if (!esEdicion) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sugerencias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _tituloCtrl.text = _sugerencias[i],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(_sugerencias[i],
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Fecha + Hora en fila
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _seleccionarFecha,
              child: _CampoSelector(
                icon: Icons.calendar_today_rounded,
                label: 'Fecha',
                valor: _formatFecha(_fecha),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _seleccionarHora,
              child: _CampoSelector(
                icon: Icons.access_time_rounded,
                label: 'Hora',
                valor: _hora != null ? _hora!.format(context) : 'Opcional',
                suave: _hora == null,
              ),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Selector cliente
        if (widget.clientes.isNotEmpty)
          GestureDetector(
            onTap: _seleccionarCliente,
            child: _CampoSelector(
              icon: Icons.person_outline_rounded,
              label: 'Cliente',
              valor: _clienteNombre ?? 'Sin cliente específico',
              suave: _clienteNombre == null,
              trailing: _clienteNombre != null
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _clienteId = null;
                        _clienteNombre = null;
                      }),
                      child: const Icon(Icons.close_rounded, size: 16,
                          color: AppColors.textMuted),
                    )
                  : null,
            ),
          ),

        const SizedBox(height: 24),

        // Botón guardar
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _guardando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(esEdicion ? 'Guardar cambios' : 'Crear recordatorio',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _seleccionarCliente() async {
    final seleccionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Seleccionar cliente',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.clientes.length,
              itemBuilder: (_, i) {
                final c = widget.clientes[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text((c['nombre'] as String)[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                  title: Text(c['nombre'] as String,
                      style: GoogleFonts.poppins(fontSize: 14)),
                  subtitle: c['telefono'] != null
                      ? Text(c['telefono'] as String,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textMuted))
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
    if (seleccionado != null) {
      setState(() {
        _clienteId = seleccionado['id'] as String;
        _clienteNombre = seleccionado['nombre'] as String;
      });
    }
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe qué tienes que hacer'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _guardando = true);
    try {
      final db = await LocalDatabase.database;
      final fechaStr =
          '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';
      final horaStr = _hora != null
          ? '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}'
          : null;

      if (widget.recordatorio != null) {
        await db.update(
          'recordatorios',
          {
            'titulo': titulo,
            'fecha': fechaStr,
            'hora': horaStr,
            'cliente_id': _clienteId,
            'cliente_nombre': _clienteNombre,
          },
          where: 'id = ?',
          whereArgs: [widget.recordatorio!['id']],
        );
      } else {
        await db.insert('recordatorios', {
          'id': const Uuid().v4(),
          'empresa_id': widget.empresaId,
          'titulo': titulo,
          'fecha': fechaStr,
          'hora': horaStr,
          'cliente_id': _clienteId,
          'cliente_nombre': _clienteNombre,
          'completado': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  String _formatFecha(DateTime d) {
    final hoy = DateTime.now();
    final diff = d.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }
}

class _CampoSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final bool suave;
  final Widget? trailing;

  const _CampoSelector({
    required this.icon, required this.label, required this.valor,
    this.suave = false, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textMuted)),
          Text(valor, style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: suave ? FontWeight.normal : FontWeight.w600,
              color: suave ? AppColors.textMuted : AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
        ])),
        if (trailing != null) trailing!
        else const Icon(Icons.chevron_right_rounded,
            size: 16, color: AppColors.textMuted),
      ]),
    );
  }
}
