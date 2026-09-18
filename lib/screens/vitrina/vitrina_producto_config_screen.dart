import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class VitrinaProductoConfigSheet extends StatefulWidget {
  final Map<String, dynamic> producto;
  final Function(Map<String, dynamic>) onSave;

  const VitrinaProductoConfigSheet({
    super.key,
    required this.producto,
    required this.onSave,
  });

  @override
  State<VitrinaProductoConfigSheet> createState() => _VitrinaProductoConfigSheetState();
}

class _VitrinaProductoConfigSheetState extends State<VitrinaProductoConfigSheet> {
  late bool _visible;
  late bool _enOferta;
  late double _precioOriginal;
  double? _precioOferta;
  double? _descuentoPct;
  late String _disponibilidad;
  DateTime? _fechaDisponibilidad;

  final _pctCtrl = TextEditingController();
  final _precioOfertaCtrl = TextEditingController();

  static const _disponibilidades = [
    {'value': 'stock',   'label': 'En stock',           'icon': Icons.check_circle_outline, 'color': 0xFF0F7B5B},
    {'value': 'hoy',     'label': 'Disponible hoy',     'icon': Icons.today_rounded,        'color': 0xFF3b82f6},
    {'value': 'manana',  'label': 'Disponible mañana',  'icon': Icons.wb_sunny_outlined,    'color': 0xFFf97316},
    {'value': 'pronto',  'label': 'Disponible pronto',  'icon': Icons.schedule_rounded,     'color': 0xFF8b5cf6},
    {'value': 'fecha',   'label': 'Fecha específica',   'icon': Icons.calendar_month_rounded,'color': 0xFFec4899},
  ];

  @override
  void initState() {
    super.initState();
    _visible       = widget.producto['en_vitrina'] as bool? ?? true;
    _precioOriginal = (widget.producto['precio_venta'] as num?)?.toDouble() ?? 0;
    _enOferta      = widget.producto['precio_oferta'] != null ||
                     widget.producto['descuento_porcentaje'] != null;
    _precioOferta  = (widget.producto['precio_oferta'] as num?)?.toDouble();
    _descuentoPct  = (widget.producto['descuento_porcentaje'] as num?)?.toDouble();
    _disponibilidad = widget.producto['disponibilidad'] as String? ?? 'stock';
    final fechaStr = widget.producto['fecha_disponibilidad'] as String?;
    if (fechaStr != null) _fechaDisponibilidad = DateTime.tryParse(fechaStr);

    if (_descuentoPct != null) {
      _pctCtrl.text = _descuentoPct!.toStringAsFixed(0);
    } else if (_precioOferta != null && _precioOriginal > 0) {
      final pct = ((_precioOriginal - _precioOferta!) / _precioOriginal) * 100;
      _pctCtrl.text = pct.toStringAsFixed(0);
      _descuentoPct = pct;
    }
    if (_precioOferta != null) {
      _precioOfertaCtrl.text = _precioOferta!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _pctCtrl.dispose();
    _precioOfertaCtrl.dispose();
    super.dispose();
  }

  void _onPctChanged(String val) {
    final pct = double.tryParse(val);
    if (pct != null && pct > 0 && pct < 100) {
      setState(() {
        _descuentoPct = pct;
        _precioOferta = _precioOriginal * (1 - pct / 100);
        _precioOfertaCtrl.text = _precioOferta!.toStringAsFixed(0);
      });
    }
  }

  void _onPrecioOfertaChanged(String val) {
    final precio = double.tryParse(val);
    if (precio != null && precio > 0 && precio < _precioOriginal) {
      setState(() {
        _precioOferta = precio;
        _descuentoPct = ((_precioOriginal - precio) / _precioOriginal) * 100;
        _pctCtrl.text = _descuentoPct!.toStringAsFixed(0);
      });
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaDisponibilidad ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fechaDisponibilidad = picked);
  }

  void _guardar() {
    final updated = Map<String, dynamic>.from(widget.producto);
    updated['en_vitrina']           = _visible;
    updated['precio_oferta']        = _enOferta ? _precioOferta : null;
    updated['descuento_porcentaje'] = _enOferta ? _descuentoPct : null;
    updated['disponibilidad']       = _disponibilidad;
    updated['fecha_disponibilidad'] = _disponibilidad == 'fecha'
        ? _fechaDisponibilidad?.toIso8601String().split('T')[0]
        : null;
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final stock = (widget.producto['stock_actual'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          )),

          // Header producto
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.producto['nombre'] as String? ?? '',
                  style: GoogleFonts.poppins(fontSize: 15,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('Precio: ${AppFormatters.moneda(_precioOriginal)} · Stock: ${stock.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            ])),
          ]),

          const SizedBox(height: 24),

          // SECCIÓN: Visibilidad
          _sectionTitle('Visibilidad en vitrina'),
          const SizedBox(height: 10),
          _toggleRow(
            icon: Icons.visibility_rounded,
            label: _visible ? 'Visible al público' : 'Oculto al público',
            subtitle: _visible ? 'Los clientes pueden ver este producto' : 'El producto no aparece en la vitrina',
            value: _visible,
            color: _visible ? AppColors.success : AppColors.textMuted,
            onChanged: (v) => setState(() => _visible = v),
          ),

          const SizedBox(height: 20),

          // SECCIÓN: Oferta
          _sectionTitle('Oferta / Descuento'),
          const SizedBox(height: 10),
          _toggleRow(
            icon: Icons.local_offer_rounded,
            label: 'Producto en oferta',
            subtitle: 'Muestra precio tachado y precio de oferta',
            value: _enOferta,
            color: AppColors.danger,
            onChanged: (v) => setState(() {
              _enOferta = v;
              if (!v) { _descuentoPct = null; _precioOferta = null; }
            }),
          ),

          if (_enOferta) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                // Precio original tachado → precio oferta
                if (_precioOferta != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(AppFormatters.moneda(_precioOriginal),
                          style: GoogleFonts.poppins(
                              fontSize: 18, color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 12),
                      Text(AppFormatters.moneda(_precioOferta!),
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: AppColors.danger)),
                      if (_descuentoPct != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('-${_descuentoPct!.toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ]),
                  ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _pctCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onPctChanged,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Descuento (%)',
                        suffixText: '%',
                        hintText: '20',
                        isDense: true,
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _precioOfertaCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onPrecioOfertaChanged,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Precio oferta',
                        prefixText: 'RD\$ ',
                        hintText: '0',
                        isDense: true,
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // SECCIÓN: Disponibilidad
          _sectionTitle('Disponibilidad'),
          const SizedBox(height: 4),
          Text('¿Cuándo pueden pedirlo o retirarlo?',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8, runSpacing: 8,
            children: _disponibilidades.map((d) {
              final val = d['value'] as String;
              final selected = _disponibilidad == val;
              final color = Color(d['color'] as int);
              final icon  = d['icon'] as IconData;
              return GestureDetector(
                onTap: () => setState(() => _disponibilidad = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : AppColors.cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 15,
                        color: selected ? color : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(d['label'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? color : AppColors.textSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),

          if (_disponibilidad == 'fecha') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFec4899).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFec4899).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Color(0xFFec4899), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _fechaDisponibilidad != null
                        ? AppFormatters.fecha(_fechaDisponibilidad)
                        : 'Toca para seleccionar la fecha',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _fechaDisponibilidad != null
                            ? AppColors.textPrimary : AppColors.textMuted,
                        fontWeight: _fechaDisponibilidad != null
                            ? FontWeight.w600 : FontWeight.w400),
                  )),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 20),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardar,
              child: Text('Aplicar cambios',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.poppins(fontSize: 13,
          fontWeight: FontWeight.w700, color: AppColors.textSecondary));

  Widget _toggleRow({
    required IconData icon, required String label,
    required String subtitle, required bool value,
    required Color color, required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.06) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.3) : AppColors.cardBorder,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: value ? color : AppColors.textMuted, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: value ? color : AppColors.textPrimary)),
          Text(subtitle, style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textMuted)),
        ])),
        Switch(value: value, onChanged: onChanged,
            activeColor: color, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }
}
