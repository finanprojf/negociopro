import 'package:uuid/uuid.dart';
import '../models/cierre_dia_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class CierreDiaService {
  static const _uuid = Uuid();

  static Future<Map<String, dynamic>> calcularResumenHoy() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId()
          .timeout(const Duration(seconds: 10));
      if (empresaId == null) return {};

      final db = await LocalDatabase.database
          .timeout(const Duration(seconds: 10));

      // Filtrar desde el último cuadre, no desde medianoche
      String inicio = '2000-01-01T00:00:00.000Z';
      final cierres = await db.query('cierres_dia',
          where: 'empresa_id = ?', whereArgs: [empresaId],
          orderBy: 'created_at DESC', limit: 1);
      if (cierres.isNotEmpty && cierres.first['created_at'] != null) {
        inicio = cierres.first['created_at'] as String;
      }

      // ── 1-4: Queries en paralelo ─────────────────────────────
      final queryResults = await Future.wait([
        db.query('ventas',
            where: "empresa_id = ? AND estado = 'completada' AND created_at >= ?",
            whereArgs: [empresaId, inicio]),
        db.query('abonos_fiado',
            where: "empresa_id = ? AND created_at >= ?",
            whereArgs: [empresaId, inicio]),
        db.query('abonos_apartado',
            where: "empresa_id = ? AND created_at >= ?",
            whereArgs: [empresaId, inicio]),
        db.query('gastos',
            where: "empresa_id = ? AND created_at >= ?",
            whereArgs: [empresaId, inicio]),
      ]);
      final ventasRows        = queryResults[0];
      final abonosFiadoRows   = queryResults[1];
      final abonosApartadoRows = queryResults[2];
      final gastosRows        = queryResults[3];

      double ventasEfectivo = 0, ventasTarjeta = 0,
             ventasTransferencia = 0, ventasFiado = 0;
      int cantVentas = 0;
      final ventaIds = <String>[];

      for (final v in ventasRows) {
        final total = (v['total'] as num? ?? 0).toDouble();
        final tipo  = (v['tipo_pago'] as String? ?? 'efectivo').toLowerCase();
        cantVentas++;
        final id = v['id'] as String?;
        if (id != null) ventaIds.add(id);
        switch (tipo) {
          case 'efectivo':      ventasEfectivo      += total; break;
          case 'tarjeta':       ventasTarjeta       += total; break;
          case 'transferencia': ventasTransferencia += total; break;
          case 'fiado':         ventasFiado         += total; break;
          default:              ventasEfectivo      += total;
        }
      }

      double abonosFiadoEfectivo = 0, abonosFiadoTransferencia = 0,
             abonosFiadoTarjeta = 0, totalAbonosFiado = 0;
      for (final a in abonosFiadoRows) {
        final monto  = (a['monto'] as num? ?? 0).toDouble();
        final metodo = (a['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
        totalAbonosFiado += monto;
        switch (metodo) {
          case 'efectivo':      abonosFiadoEfectivo      += monto; break;
          case 'transferencia': abonosFiadoTransferencia += monto; break;
          case 'tarjeta':       abonosFiadoTarjeta       += monto; break;
          default:              abonosFiadoEfectivo      += monto;
        }
      }

      double abonosApartadoEfectivo = 0, abonosApartadoTransferencia = 0,
             abonosApartadoTarjeta = 0, totalAbonosApartado = 0;
      for (final a in abonosApartadoRows) {
        final monto  = (a['monto'] as num? ?? 0).toDouble();
        final metodo = (a['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
        totalAbonosApartado += monto;
        switch (metodo) {
          case 'efectivo':      abonosApartadoEfectivo      += monto; break;
          case 'transferencia': abonosApartadoTransferencia += monto; break;
          case 'tarjeta':       abonosApartadoTarjeta       += monto; break;
          default:              abonosApartadoEfectivo      += monto;
        }
      }

      double gastosEfectivo = 0, gastosTransferencia = 0,
             gastosTarjeta = 0, totalGastos = 0;
      for (final g in gastosRows) {
        final monto  = (g['monto'] as num? ?? 0).toDouble();
        final metodo = (g['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
        totalGastos += monto;
        switch (metodo) {
          case 'efectivo':      gastosEfectivo      += monto; break;
          case 'transferencia': gastosTransferencia += monto; break;
          case 'tarjeta':       gastosTarjeta       += monto; break;
          default:              gastosEfectivo      += monto;
        }
      }

      // ── 5. GANANCIA REAL — una sola query masiva ──────────────
      double gananciaBruta = 0;
      if (ventaIds.isNotEmpty) {
        try {
          // Traer todos los detalles de todas las ventas en una sola query
          final placeholders = ventaIds.map((_) => '?').join(',');
          final detalles = await db.rawQuery(
            'SELECT d.cantidad, d.precio_unitario, d.producto_id, '
            'p.precio_compra, p.es_elaborado, p.costo_produccion, p.unidades_producidas '
            'FROM detalle_ventas d '
            'LEFT JOIN productos p ON p.id = d.producto_id '
            'WHERE d.venta_id IN ($placeholders)',
            ventaIds,
          );
          for (final d in detalles) {
            final cantidad    = (d['cantidad'] as num? ?? 0).toDouble();
            final precioVenta = (d['precio_unitario'] as num? ?? 0).toDouble();
            final esElab      = (d['es_elaborado'] as int? ?? 0) == 1;
            double costo;
            if (esElab) {
              final cp  = (d['costo_produccion'] as num? ?? 0).toDouble();
              final up  = (d['unidades_producidas'] as num? ?? 1).toDouble();
              costo = up > 0 ? cp / up : 0;
            } else {
              costo = (d['precio_compra'] as num? ?? 0).toDouble();
            }
            gananciaBruta += (precioVenta - costo) * cantidad;
          }
        } catch (_) {
          // Si falla el JOIN, ganancia real = 0 (no bloquea el cierre)
          gananciaBruta = 0;
        }
      }
      final gananciaReal = gananciaBruta - totalGastos;

      // ── 6. TOTALES ────────────────────────────────────────────
      final totalVentas = ventasEfectivo + ventasTarjeta +
                          ventasTransferencia + ventasFiado;
      final ingresoReal = ventasEfectivo + ventasTarjeta +
                          ventasTransferencia +
                          totalAbonosFiado + totalAbonosApartado;
      final ganancia         = ingresoReal - totalGastos;
      final efectivoEsperado = ventasEfectivo + abonosFiadoEfectivo +
                               abonosApartadoEfectivo - gastosEfectivo;
      final totalBanco       = ventasTarjeta + ventasTransferencia +
                               abonosFiadoTarjeta + abonosFiadoTransferencia +
                               abonosApartadoTarjeta + abonosApartadoTransferencia -
                               gastosTarjeta - gastosTransferencia;

      return {
        'total_ventas':               totalVentas,
        'cantidad_ventas':            cantVentas,
        'ventas_efectivo':            ventasEfectivo,
        'ventas_tarjeta':             ventasTarjeta,
        'ventas_transferencia':       ventasTransferencia,
        'ventas_fiado':               ventasFiado,
        'abonos_fiado_total':         totalAbonosFiado,
        'abonos_fiado_efectivo':      abonosFiadoEfectivo,
        'abonos_fiado_transferencia': abonosFiadoTransferencia,
        'abonos_fiado_tarjeta':       abonosFiadoTarjeta,
        'abonos_apartado_total':      totalAbonosApartado,
        'abonos_apartado_efectivo':   abonosApartadoEfectivo,
        'abonos_apartado_transferencia': abonosApartadoTransferencia,
        'abonos_apartado_tarjeta':    abonosApartadoTarjeta,
        'total_gastos':               totalGastos,
        'gastos_efectivo':            gastosEfectivo,
        'gastos_transferencia':       gastosTransferencia,
        'gastos_tarjeta':             gastosTarjeta,
        'ingreso_real':               ingresoReal,
        'ganancia':                   ganancia,
        'ganancia_real':              gananciaReal,
        'efectivo_esperado':          efectivoEsperado,
        'total_banco':                totalBanco,
      };
    } catch (e) {
      // Retorna mapa vacío para que la pantalla muestre error en lugar de colgarse
      return {'_error': e.toString()};
    }
  }

  static Future<CierreDiaModel?> guardarCierre({
    required double efectivoContado,
    required Map<String, dynamic> resumen,
    String? notas,
  }) async {
    try {
      final empresaId = await SupabaseService.getEmpresaId()
          .timeout(const Duration(seconds: 10));
      if (empresaId == null) return null;

      final efectivoEsperado = (resumen['efectivo_esperado'] as num? ?? 0).toDouble();
      final diferencia       = efectivoContado - efectivoEsperado;
      final ahora            = DateTime.now();

      final cierre = CierreDiaModel(
        id:               _uuid.v4(),
        empresaId:        empresaId,
        fecha:            ahora,
        totalVentas:      (resumen['total_ventas'] as num? ?? 0).toDouble(),
        cantidadVentas:   (resumen['cantidad_ventas'] as num? ?? 0).toInt(),
        totalGastos:      (resumen['total_gastos'] as num? ?? 0).toDouble(),
        ganancia:         (resumen['ganancia'] as num? ?? 0).toDouble(),
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
          await SupabaseService.client
              .from('cierres_dia')
              .upsert(online)
              .timeout(const Duration(seconds: 15));
          await LocalDatabase.marcarSynced('cierres_dia', cierre.id);
        } catch (_) {
          // Fallo de sync — queda en cola para después, no bloquea
        }
      }

      return cierre;
    } catch (e) {
      return null;
    }
  }

  static Future<List<CierreDiaModel>> getHistorial() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId()
          .timeout(const Duration(seconds: 10));
      if (empresaId == null) return [];
      final rows = await LocalDatabase.consultar('cierres_dia', empresaId);
      return rows.map((m) => CierreDiaModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> eliminarCierre(String cierreId) async {
    try {
      final db = await LocalDatabase.database;
      await db.delete('cierres_dia', where: 'id = ?', whereArgs: [cierreId]);
      try {
        await SupabaseService.client
            .from('cierres_dia')
            .delete()
            .eq('id', cierreId)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }
}
