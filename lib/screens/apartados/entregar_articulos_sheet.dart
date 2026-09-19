import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/apartado_model.dart';
import '../../utils/formatters.dart';
import '../../services/apartado_service.dart';
import '../../services/local_database.dart';
import '../seguridad/pin_entrada_dialog.dart';

/// Sheet para marcar artículos de un apartado como entregados.
/// Funciona con apartados nuevos (con líneas en apartado_productos)
/// y con apartados viejos (sin líneas — muestra el apartado como ítem virtual).
class EntregarArticulosSheet extends StatefulWidget {
  final ApartadoModel apartado;
  final List<Map<String, dynamic>> lineas;
  final VoidCallback onCambio;

  const EntregarArticulosSheet({
    super.key,
    required this.apartado,
    required this.lineas,
    required this.onCambio,
  });

  @override
  State<EntregarArticulosSheet> createState() => _EntregarArticulosSheetState();
}

class _EntregarArticulosSheetState extends State<EntregarArticulosSheet> {
  late List<Map<String, dynamic>> _lineas;

  @override
  void initState() {
    super.initState();
    // Apartados viejos sin líneas: mostrar el apartado mismo como ítem entregable
    if (widget.lineas.isEmpty) {
      _lineas = [{
        'id': null,
        'nombre': widget.apartado.descripcion,
        'cantidad': 1.0,
        'precio': widget.apartado.montoTotal,
        'entregado': 0,
        'fecha_entrega': null,
        '_virtual': true,
      }];
    } else {
      _lineas = List.from(widget.lineas);
    }
  }

  Future<void> _toggleEntregado(int idx) async {
    final linea = _lineas[idx];
    final nuevoValor = (linea['entregado'] as int? ?? 0) == 0 ? 1 : 0;

    if (nuevoValor == 1) {
      final pinOk = await mostrarDialogoPinRapido(context,
          titulo: 'Autorizar entrega de artículo');
      if (!pinOk) return;
    }

    // Línea virtual: insertarla en BD antes de marcar
    String lineaId = linea['id'] as String? ?? '';
    if (linea['id'] == null) {
      lineaId = const Uuid().v4();
      final db = await LocalDatabase.database;
      await db.insert('apartado_productos', {
        'id': lineaId,
        'apartado_id': widget.apartado.id,
        'empresa_id': widget.apartado.empresaId,
        'producto_id': null,
        'nombre': linea['nombre'] as String,
        'cantidad': (linea['cantidad'] as num).toDouble(),
        'precio': (linea['precio'] as num).toDouble(),
        'costo': null,
        'entregado': 0,
        'fecha_entrega': null,
        'synced': 0,
      });
      setState(() {
        _lineas[idx] = Map.from(_lineas[idx])
          ..['id'] = lineaId
          ..['_virtual'] = false;
      });
    }

    await ApartadoService.marcarLineaEntregada(lineaId, nuevoValor == 1);
    setState(() {
      _lineas[idx] = Map.from(_lineas[idx])
        ..['entregado'] = nuevoValor
        ..['fecha_entrega'] = nuevoValor == 1
            ? DateTime.now().toIso8601String()
            : null;
    });
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Entregar artículos',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(widget.apartado.descripcion,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 12, color: AppColors.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _lineas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final l = _lineas[i];
              final entregado = (l['entregado'] as int? ?? 0) == 1;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: entregado ? AppColors.successSurface : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: entregado
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.cardBorder,
                    width: entregado ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: entregado
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.colorApartados.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      entregado
                          ? Icons.check_circle_rounded
                          : Icons.inventory_2_outlined,
                      color: entregado ? AppColors.success : AppColors.colorApartados,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l['nombre'] as String? ?? '',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          decoration: entregado ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textMuted,
                        )),
                    const SizedBox(height: 2),
                    Text('${(l['cantidad'] as num).toStringAsFixed(0)} × '
                        '${AppFormatters.moneda((l['precio'] as num).toDouble())}',
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontSize: 12, color: AppColors.textMuted)),
                    if (entregado && l['fecha_entrega'] != null)
                      Text('✓ Entregado ${AppFormatters.fecha(DateTime.tryParse(l["fecha_entrega"] as String? ?? ""))}',
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 11, color: AppColors.success,
                              fontWeight: FontWeight.w500)),
                  ])),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _toggleEntregado(i),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: entregado
                          ? AppColors.surfaceAlt : AppColors.success,
                      foregroundColor: entregado
                          ? AppColors.textMuted : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: entregado
                              ? AppColors.cardBorder : AppColors.success,
                        ),
                      ),
                    ),
                    child: Text(entregado ? 'Quitar' : 'Entregar',
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
