import 'package:uuid/uuid.dart';
import '../models/cierre_dia_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class CierreDiaService {
  static const _uuid = Uuid();

  /// Calcula el resumen completo del día con lógica contable correcta.
  static Future<Map<String, dynamic>> calcularResumenHoy() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return {};

    final db = await LocalDatabase.database;

    // Filtrar desde el último cuadre, no desde medianoche
    String inicio = '2000-01-01T00:00:00.000Z';
    final cierres = await db.query('cierres_dia',
        where: 'empresa_id = ?', whereArgs: [empresaId],
        orderBy: 'created_at DESC', limit: 1);
    if (cierres.isNotEmpty && cierres.first['created_at'] != null) {
      inicio = cierres.first['created_at'] as String;
    }

    // ── 1. VENTAS DEL PERÍODO ──────────────────────────────────
    final ventasRows = await db.query(
      'ventas',
      where: "empresa_id = ? AND estado = 'completada' AND created_at >= ?",
      whereArgs: [empresaId, inicio],
    );

    double ventasEfectivo      = 0;
    double ventasTarjeta       = 0;
    double ventasTransferencia = 0;
    double ventasFiado         = 0; // deuda — NO entra en caja
    int    cantVentas          = 0;

    for (final v in ventasRows) {
      final total = (v['total'] as num).toDouble();
      final tipo  = (v['tipo_pago'] as String? ?? 'efectivo').toLowerCase();
      cantVentas++;
      switch (tipo) {
        case 'efectivo':     ventasEfectivo      += total; break;
        case 'tarjeta':      ventasTarjeta       += total; break;
        case 'transferencia':ventasTransferencia += total; break;
        case 'fiado':        ventasFiado         += total; break;
        default:             ventasEfectivo      += total;
      }
    }

    // ── 2. ABONOS DE FIADO COBRADOS HOY ───────────────────────
    // Solo los que entran en efectivo a la caja
    final abonosFiadoRows = await db.query(
      'abonos_fiado',
      where: "empresa_id = ? AND created_at >= ?",
      whereArgs: [empresaId, inicio],
    );

    double abonosFiadoEfectivo      = 0;
    double abonosFiadoTransferencia = 0;
    double abonosFiadoTarjeta       = 0;
    double totalAbonosFiado         = 0;

    for (final a in abonosFiadoRows) {
      final monto = (a['monto'] as num).toDouble();
      final metodo = (a['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
      totalAbonosFiado += monto;
      switch (metodo) {
        case 'efectivo':      abonosFiadoEfectivo      += monto; break;
        case 'transferencia': abonosFiadoTransferencia += monto; break;
        case 'tarjeta':       abonosFiadoTarjeta       += monto; break;
        default:              abonosFiadoEfectivo      += monto;
      }
    }

    // ── 3. ABONOS DE APARTADO COBRADOS HOY ────────────────────
    final abonosApartadoRows = await db.query(
      'abonos_apartado',
      where: "empresa_id = ? AND created_at >= ?",
      whereArgs: [empresaId, inicio],
    );

    double abonosApartadoEfectivo      = 0;
    double abonosApartadoTransferencia = 0;
    double abonosApartadoTarjeta       = 0;
    double totalAbonosApartado         = 0;

    for (final a in abonosApartadoRows) {
      final monto  = (a['monto'] as num).toDouble();
      final metodo = (a['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
      totalAbonosApartado += monto;
      switch (metodo) {
        case 'efectivo':      abonosApartadoEfectivo      += monto; break;
        case 'transferencia': abonosApartadoTransferencia += monto; break;
        case 'tarjeta':       abonosApartadoTarjeta       += monto; break;
        default:              abonosApartadoEfectivo      += monto;
      }
    }

    // ── 4. GASTOS DEL DÍA ─────────────────────────────────────
    final gastosRows = await db.query(
      'gastos',
      where: "empresa_id = ? AND created_at >= ?",
      whereArgs: [empresaId, inicio],
    );

    double gastosEfectivo      = 0;
    double gastosTransferencia = 0;
    double gastosTarjeta       = 0;
    double totalGastos         = 0;

    for (final g in gastosRows) {
      final monto  = (g['monto'] as num).toDouble();
      final metodo = (g['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
      totalGastos += monto;
      switch (metodo) {
        case 'efectivo':      gastosEfectivo      += monto; break;
        case 'transferencia': gastosTransferencia += monto; break;
        case 'tarjeta':       gastosTarjeta       += monto; break;
        default:              gastosEfectivo      += monto;
      }
    }

    // ── 5. GANANCIA REAL (margen bruto) ──────────────────────
    // Para cada item vendido hoy: (precio_venta - costo) * cantidad
    double gananciaBruta = 0;
    for (final v in ventasRows) {
      final ventaId = v['id'] as String;
      final detalles = await db.query('detalle_ventas',
          where: 'venta_id = ?', whereArgs: [ventaId]);
      for (final d in detalles) {
        final cantidad = (d['cantidad'] as num).toDouble();
        final precioVenta = (d['precio_unitario'] as num).toDouble();
        final productoId = d['producto_id'] as String?;
        if (productoId == null) continue;
        final prods = await db.query('productos',
            where: 'id = ?', whereArgs: [productoId]);
        if (prods.isEmpty) continue;
        final prod = prods.first;
        final esElaborado = (prod['es_elaborado'] as int? ?? 0) == 1;
        double costo;
        if (esElaborado) {
          final costoProduccion = (prod['costo_produccion'] as num? ?? 0).toDouble();
          final unidades = (prod['unidades_producidas'] as num? ?? 1).toDouble();
          costo = unidades > 0 ? costoProduccion / unidades : 0;
        } else {
          costo = (prod['precio_compra'] as num? ?? 0).toDouble();
        }
        gananciaBruta += (precioVenta - costo) * cantidad;
      }
    }
    final gananciaReal = gananciaBruta - totalGastos;

    // ── 6. TOTALES CONSOLIDADOS ────────────────────────────────
    final totalVentas = ventasEfectivo + ventasTarjeta + ventasTransferencia + ventasFiado;

    // Dinero real ingresado hoy (excluye fiado = deuda)
    final ingresoReal = ventasEfectivo + ventasTarjeta + ventasTransferencia
        + totalAbonosFiado + totalAbonosApartado;

    // Ganancia bruta = ingresos reales − gastos totales
    final ganancia = ingresoReal - totalGastos;

    // ── 7. CAJA FÍSICA ESPERADA ────────────────────────────────
    // Solo movimientos en efectivo
    final efectivoEsperado = ventasEfectivo
        + abonosFiadoEfectivo
        + abonosApartadoEfectivo
        - gastosEfectivo;

    // Total banco/digital
    final totalBanco = ventasTarjeta + ventasTransferencia
        + abonosFiadoTarjeta + abonosFiadoTransferencia
        + abonosApartadoTarjeta + abonosApartadoTransferencia
        - gastosTarjeta - gastosTransferencia;

    return {
      // Ventas
      'total_ventas':            totalVentas,
      'cantidad_ventas':         cantVentas,
      'ventas_efectivo':         ventasEfectivo,
      'ventas_tarjeta':          ventasTarjeta,
      'ventas_transferencia':    ventasTransferencia,
      'ventas_fiado':            ventasFiado,
      // Abonos fiado
      'abonos_fiado_total':      totalAbonosFiado,
      'abonos_fiado_efectivo':   abonosFiadoEfectivo,
      'abonos_fiado_transferencia': abonosFiadoTransferencia,
      'abonos_fiado_tarjeta':    abonosFiadoTarjeta,
      // Abonos apartado
      'abonos_apartado_total':   totalAbonosApartado,
      'abonos_apartado_efectivo':abonosApartadoEfectivo,
      'abonos_apartado_transferencia': abonosApartadoTransferencia,
      'abonos_apartado_tarjeta': abonosApartadoTarjeta,
      // Gastos
      'total_gastos':            totalGastos,
      'gastos_efectivo':         gastosEfectivo,
      'gastos_transferencia':    gastosTransferencia,
      'gastos_tarjeta':          gastosTarjeta,
      // Resumen
      'ingreso_real':            ingresoReal,
      'ganancia':                ganancia,
      'ganancia_real':            gananciaReal,
      'efectivo_esperado':       efectivoEsperado,
      'total_banco':             totalBanco,
    };
  }

  static Future<CierreDiaModel?> guardarCierre({
    required double efectivoContado,
    required Map<String, dynamic> resumen,
    String? notas,
  }) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return null;

    final efectivoEsperado = (resumen['efectivo_esperado'] as num).toDouble();
    final diferencia       = efectivoContado - efectivoEsperado;
    final ahora            = DateTime.now();

    final cierre = CierreDiaModel(
      id:               _uuid.v4(),
      empresaId:        empresaId,
      fecha:            ahora,
      totalVentas:      (resumen['total_ventas'] as num).toDouble(),
      cantidadVentas:   (resumen['cantidad_ventas'] as num).toInt(),
      totalGastos:      (resumen['total_gastos'] as num).toDouble(),
      ganancia:         (resumen['ganancia'] as num).toDouble(),
      gananciaReal:     (resumen['ganancia_real'] as num? ?? 0).toDouble(),
      efectivoEsperado: efectivoEsperado,
      efectivoContado:  efectivoContado,
      diferencia:       diferencia,
      notas:            notas,
      synced:           0,
      createdAt:        ahora,
    );

    final map = cierre.toMap();
    map['synced']     = 0;
    map['created_at'] = ahora.toUtc().toIso8601String();
    await LocalDatabase.insertar('cierres_dia', map);

    if (await SupabaseService.isOnlineAsync) {
      try {
        final online = cierre.toMap();
        online['created_at'] = ahora.toUtc().toIso8601String();
        online.remove('synced');
        await SupabaseService.client.from('cierres_dia').upsert(online);
        await LocalDatabase.marcarSynced('cierres_dia', cierre.id);
      } catch (_) {}
    }

    return cierre;
  }

  static Future<List<CierreDiaModel>> getHistorial() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];
    final rows = await LocalDatabase.consultar('cierres_dia', empresaId);
    return rows.map((m) => CierreDiaModel.fromMap(m)).toList();
  }
}
