import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../services/cierre_dia_service.dart';
import '../../services/cuadre_automatico_service.dart';
import '../../models/cierre_dia_model.dart';

class CierreDiaScreen extends StatefulWidget {
  const CierreDiaScreen({super.key});
  @override
  State<CierreDiaScreen> createState() => _CierreDiaScreenState();
}

class _CierreDiaScreenState extends State<CierreDiaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool _cargando  = true;
  bool _guardando = false;
  Map<String, dynamic> _r = {};
  List<CierreDiaModel> _historial = [];

  final _efectivoCtrl = TextEditingController();
  final _notasCtrl    = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  // Auto-cuadre
  bool _autoActivo    = false;
  int  _autoHora      = 22;
  int  _autoMinuto    = 0;
  int  _autoIntervalo = 0; // 0=hora fija, 8/12/24=cada X horas

  // Tiempo real
  double _efectivoContado  = 0;
  double _diferencia       = 0;
  double _efectivoEsperado = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _efectivoCtrl.addListener(_actualizarCuadre);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _efectivoCtrl.removeListener(_actualizarCuadre);
    _efectivoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _actualizarCuadre() {
    final v = double.tryParse(_efectivoCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _efectivoContado = v;
      _diferencia      = v - _efectivoEsperado;
    });
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final activo    = await CuadreAutomaticoService.isActivo();
    final hora      = await CuadreAutomaticoService.getHora();
    final minuto    = await CuadreAutomaticoService.getMinuto();
    final intervalo = await CuadreAutomaticoService.getIntervalo();
    final r = await CierreDiaService.calcularResumenHoy();
    final h = await CierreDiaService.getHistorial();
    if (!mounted) return;
    setState(() {
      _r                = r;
      _historial        = h;
      _efectivoEsperado = _d('efectivo_esperado');
      _diferencia       = _efectivoContado - _efectivoEsperado;
      _autoActivo       = activo;
      _autoHora         = hora;
      _autoMinuto       = minuto;
      _autoIntervalo    = intervalo;
      _cargando         = false;
    });
  }

  double _d(String k) => (_r[k] as num? ?? 0).toDouble();
  int    _i(String k) => (_r[k] as num? ?? 0).toInt();

  Future<void> _realizarCierre() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final cierre = await CierreDiaService.guardarCierre(
      efectivoContado: _efectivoContado,
      resumen:         _r,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    setState(() => _guardando = false);
    if (!mounted) return;
    if (cierre != null) {
      _efectivoCtrl.clear();
      _notasCtrl.clear();
      await _cargar();
      _tabs.animateTo(1);
      _mostrarConfirmacion(cierre);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar el cierre')));
    }
  }

  void _mostrarConfirmacion(CierreDiaModel c) {
    final sobra = c.diferencia >= 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(sobra ? Icons.check_circle : Icons.warning_amber_rounded,
              color: sobra ? AppColors.success : AppColors.warning),
          const SizedBox(width: 8),
          const Text('Cuadre registrado'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _cr('Ventas del día',     AppFormatters.moneda(c.totalVentas)),
          _cr('Gastos del día',     AppFormatters.moneda(c.totalGastos)),
          _cr('Ganancia real',    AppFormatters.moneda(c.gananciaReal),
              color: c.gananciaReal >= 0 ? AppColors.success : AppColors.danger, bold: true),
          _cr('Ingreso neto',    AppFormatters.moneda(c.ganancia),
              color: AppColors.textSecondary),
          const Divider(height: 20),
          _cr('Efectivo esperado',  AppFormatters.moneda(c.efectivoEsperado)),
          _cr('Efectivo contado',   AppFormatters.moneda(c.efectivoContado)),
          _cr(sobra ? '✅ Sobra' : '⚠️ Falta',
              AppFormatters.moneda(c.diferencia.abs()),
              color: sobra ? AppColors.success : AppColors.warning, bold: true),
        ]),
        actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'))],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Text('Cuadre de Caja',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(icon: Icon(Icons.lock_clock), text: 'Nuevo Cuadre'),
          Tab(icon: Icon(Icons.history),    text: 'Historial'),
          Tab(icon: Icon(Icons.alarm),      text: 'Automático'),
        ],
      ),
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs,
            children: [_tabNuevo(), _tabHistorial(), _tabAutomatico()]),
  );

  // ══════════════════════ TAB 1 ════════════════════════════════
  Widget _tabNuevo() {
    if (_r.isEmpty) return const Center(child: Text('No hay datos del día'));

    final sobra = _diferencia >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Fecha
          _chipFecha(),
          const SizedBox(height: 16),

          // ── VENTAS ──
          _titulo('Ventas del Día', Icons.shopping_cart_rounded, AppColors.colorVentas),
          _card([
            _fila('Total ventas', _d('total_ventas'),
                bold: true, color: AppColors.colorVentas),
            _fila('Cantidad', _i('cantidad_ventas').toDouble(),
                esInt: true, sufijo: 'ventas'),
            const Divider(height: 16),
            _fila('Efectivo', _d('ventas_efectivo')),
            if (_d('ventas_tarjeta') > 0)
              _fila('Tarjeta', _d('ventas_tarjeta'), color: AppColors.info),
            if (_d('ventas_transferencia') > 0)
              _fila('Transferencia', _d('ventas_transferencia'), color: AppColors.info),
            if (_d('ventas_fiado') > 0)
              _filaTexto('Fiado (deuda, no cobrado)',
                  AppFormatters.moneda(_d('ventas_fiado')),
                  color: AppColors.colorFiado,
                  nota: 'No entra en caja'),
          ]),
          const SizedBox(height: 14),

          // ── ABONOS FIADO ──
          if (_d('abonos_fiado_total') > 0) ...[
            _titulo('Cobros de Fiado Hoy', Icons.account_balance_wallet_rounded,
                AppColors.colorFiado),
            _card([
              _fila('Total cobrado', _d('abonos_fiado_total'),
                  bold: true, color: AppColors.colorFiado),
              if (_d('abonos_fiado_efectivo') > 0)
                _fila('Efectivo', _d('abonos_fiado_efectivo')),
              if (_d('abonos_fiado_transferencia') > 0)
                _fila('Transferencia', _d('abonos_fiado_transferencia'),
                    color: AppColors.info),
              if (_d('abonos_fiado_tarjeta') > 0)
                _fila('Tarjeta', _d('abonos_fiado_tarjeta'), color: AppColors.info),
            ]),
            const SizedBox(height: 14),
          ],

          // ── ABONOS APARTADO ──
          if (_d('abonos_apartado_total') > 0) ...[
            _titulo('Cobros de Apartados Hoy', Icons.bookmark_rounded,
                AppColors.colorApartados),
            _card([
              _fila('Total cobrado', _d('abonos_apartado_total'),
                  bold: true, color: AppColors.colorApartados),
              if (_d('abonos_apartado_efectivo') > 0)
                _fila('Efectivo', _d('abonos_apartado_efectivo')),
              if (_d('abonos_apartado_transferencia') > 0)
                _fila('Transferencia', _d('abonos_apartado_transferencia'),
                    color: AppColors.info),
              if (_d('abonos_apartado_tarjeta') > 0)
                _fila('Tarjeta', _d('abonos_apartado_tarjeta'), color: AppColors.info),
            ]),
            const SizedBox(height: 14),
          ],

          // ── GASTOS ──
          _titulo('Gastos del Día', Icons.receipt_long_rounded, AppColors.colorGastos),
          _card([
            _fila('Total gastos', _d('total_gastos'),
                bold: true,
                color: _d('total_gastos') > 0 ? AppColors.danger : AppColors.textSecondary),
            if (_d('gastos_efectivo') > 0)
              _fila('En efectivo', _d('gastos_efectivo'), color: AppColors.danger),
            if (_d('gastos_transferencia') > 0)
              _fila('Transferencia', _d('gastos_transferencia'), color: AppColors.info),
            if (_d('gastos_tarjeta') > 0)
              _fila('Tarjeta', _d('gastos_tarjeta'), color: AppColors.info),
          ]),
          const SizedBox(height: 14),

          // ── RESULTADO ──
          _titulo('Resultado del Día', Icons.trending_up_rounded, AppColors.success),
          _card([
            _fila(
              _d('ganancia_real') >= 0 ? '✅ Ganancia real' : '❌ Pérdida real',
              _d('ganancia_real').abs(),
              bold: true,
              color: _d('ganancia_real') >= 0 ? AppColors.success : AppColors.danger,
            ),
            _filaTexto('  (margen de productos − gastos)',
                '', color: AppColors.textMuted),
            const Divider(height: 14),
            _fila('Ingreso neto del día', _d('ganancia'),
                color: AppColors.textSecondary),
            _filaTexto('  (ventas cobradas − gastos)',
                '', color: AppColors.textMuted),
            if (_d('total_banco') > 0)
              _filaTexto('En banco/digital',
                  AppFormatters.moneda(_d('total_banco')),
                  color: AppColors.info, nota: 'tarjeta + transferencia'),
          ]),
          const SizedBox(height: 14),

          // ── CUADRE DE CAJA ──
          _titulo('Cuadre de Caja (Efectivo)', Icons.calculate_rounded, AppColors.accent),
          _card([
            _fila('Efectivo esperado', _d('efectivo_esperado'),
                color: AppColors.textSecondary),
            const SizedBox(height: 10),

            // Campo monto contado
            Text('¿Cuánto hay físicamente en caja?',
                style: TextStyle(fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _efectivoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'RD\$ ',
                hintText: '0.00',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el monto contado';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Resultado en tiempo real
            if (_efectivoContado > 0 || _efectivoCtrl.text.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sobra
                      ? AppColors.successSurface
                      : AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sobra ? AppColors.success : AppColors.warning),
                ),
                child: Row(children: [
                  Icon(
                    sobra ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: sobra ? AppColors.success : AppColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      sobra ? 'SOBRA en caja' : 'FALTA en caja',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: sobra ? AppColors.success : AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      AppFormatters.moneda(_diferencia.abs()),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: sobra ? AppColors.success : AppColors.warning,
                        fontSize: 20,
                      ),
                    ),
                  ]),
                ]),
              ),
          ]),
          const SizedBox(height: 14),

          // Notas
          Text('Notas (opcional)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notasCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Observaciones del día...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 24),

          // Botón
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _realizarCierre,
              icon: _guardando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_clock, color: Colors.white),
              label: Text(
                _guardando ? 'Guardando...' : 'Confirmar Cuadre de Caja',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }


  // ══════════════════════ TAB 3: AUTO ════════════════════════
  Widget _tabAutomatico() {
    final intervalOpts = [
      {'label': 'Hora fija del día', 'val': 0},
      {'label': 'Cada 8 horas',      'val': 8},
      {'label': 'Cada 12 horas',     'val': 12},
      {'label': 'Cada 24 horas',     'val': 24},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titulo('Cuadre Automático', Icons.alarm_rounded, AppColors.primary),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Toggle
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activar recordatorio',
                    style: TextStyle(fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Recibirás una notificación para hacer el cuadre',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ])),
              Switch(
                value: _autoActivo,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _autoActivo = v),
              ),
            ]),

            if (_autoActivo) ...[
              const Divider(height: 24),

              // Tipo de intervalo
              Text('¿Cuándo recordar?',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _autoIntervalo,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: intervalOpts.map((o) => DropdownMenuItem<int>(
                  value: o['val'] as int,
                  child: Text(o['label'] as String),
                )).toList(),
                onChanged: (v) => setState(() => _autoIntervalo = v ?? 0),
              ),

              // Hora fija picker
              if (_autoIntervalo == 0) ...[
                const SizedBox(height: 16),
                Text('Hora del recordatorio',
                    style: TextStyle(color: AppColors.textSecondary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: _autoHora, minute: _autoMinuto),
                    );
                    if (t != null) setState(() {
                      _autoHora   = t.hour;
                      _autoMinuto = t.minute;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${_autoHora.toString().padLeft(2, '0')}:'
                        '${_autoMinuto.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Text('Toca para cambiar',
                          style: TextStyle(color: AppColors.textMuted,
                              fontSize: 12)),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              if (_autoIntervalo > 0)
                Text(
                  '⏱ La notificación se enviará cada $_autoIntervalo horas '
                  'mientras la app esté instalada.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              if (_autoIntervalo == 0)
                Text(
                  '🕐 Recibirás la notificación todos los días a las '
                  '${_autoHora.toString().padLeft(2, '0')}:'
                  '${_autoMinuto.toString().padLeft(2, '0')}.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ]),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _guardarAutoConfig,
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: Text('Guardar configuración',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _guardarAutoConfig() async {
    await CuadreAutomaticoService.guardar(
      activo:         _autoActivo,
      hora:           _autoHora,
      minuto:         _autoMinuto,
      intervaloHoras: _autoIntervalo,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_autoActivo
          ? '✅ Recordatorio activado'
          : '🔕 Recordatorio desactivado'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ══════════════════════ TAB 2 ════════════════════════════════
  Widget _tabHistorial() {
    if (_historial.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text('No hay cierres registrados',
            style: TextStyle(color: AppColors.textMuted)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historial.length,
      itemBuilder: (_, i) {
        final c     = _historial[i];
        final sobra = c.diferencia >= 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  sobra ? AppColors.successSurface : AppColors.warningSurface,
              child: Icon(
                sobra ? Icons.check_rounded : Icons.warning_amber_rounded,
                color: sobra ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(AppFormatters.fecha(c.fecha),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            subtitle: Text(
              sobra
                  ? 'Sobró ${AppFormatters.moneda(c.diferencia)}'
                  : 'Faltó ${AppFormatters.moneda(c.diferencia.abs())}',
              style: TextStyle(
                  color: sobra ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Ganancia real', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Text(AppFormatters.moneda(c.gananciaReal),
                    style: TextStyle(
                      color: c.gananciaReal >= 0 ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(children: [
                  const Divider(),
                  _cr('Ganancia real', AppFormatters.moneda(c.gananciaReal),
                      color: c.gananciaReal >= 0 ? AppColors.success : AppColors.danger,
                      bold: true),
                  _cr('Ingreso neto', AppFormatters.moneda(c.ganancia),
                      color: AppColors.textSecondary),
                  const Divider(height: 12),
                  _cr('Ventas del día',     AppFormatters.moneda(c.totalVentas)),
                  _cr('Gastos del día',     AppFormatters.moneda(c.totalGastos)),
                  _cr('Efectivo esperado',  AppFormatters.moneda(c.efectivoEsperado)),
                  _cr('Efectivo contado',   AppFormatters.moneda(c.efectivoContado)),
                  if (c.notas != null && c.notas!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('📝 ${c.notas}',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers UI ──────────────────────────────────────────────
  Widget _chipFecha() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
      const SizedBox(width: 8),
      Text('Hoy: ${AppFormatters.fecha(DateTime.now())}',
          style: GoogleFonts.poppins(
              color: AppColors.primary, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _titulo(String t, IconData ic, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(ic, color: c, size: 18),
      const SizedBox(width: 6),
      Text(t, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary, fontSize: 14)),
    ]),
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _fila(String label, double monto,
      {Color? color, bool bold = false,
       bool esInt = false, String? sufijo}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
            Text(
              esInt
                  ? '${monto.toInt()}${sufijo != null ? ' $sufijo' : ''}'
                  : AppFormatters.moneda(monto),
              style: TextStyle(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      );

  Widget _filaTexto(String label, String valor,
      {Color? color, String? nota}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
              if (nota != null)
                Text(nota, style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            ]),
            Text(valor, style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  Widget _cr(String label, String valor, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
            Text(valor, style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: 13)),
          ],
        ),
      );
}
