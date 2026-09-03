import 'detalle_venta_model.dart';

class VentaModel {
  final String id;
  final String empresaId;
  final String? clienteId;
  final String? usuarioId;
  final int? numeroVenta;
  final String tipoPago;
  final double subtotal;
  final double descuento;
  final double itbis;
  final double total;
  final double montoPagado;
  final double cambio;
  final String estado;
  final String? notas;
  final DateTime? createdAt;

  // Relaciones
  final List<DetalleVentaModel> detalles;
  final String? clienteNombre;

  VentaModel({
    required this.id,
    required this.empresaId,
    this.clienteId,
    this.usuarioId,
    this.numeroVenta,
    this.tipoPago = 'efectivo',
    this.subtotal = 0,
    this.descuento = 0,
    this.itbis = 0,
    required this.total,
    this.montoPagado = 0,
    this.cambio = 0,
    this.estado = 'completada',
    this.notas,
    this.createdAt,
    this.detalles = const [],
    this.clienteNombre,
  });

  bool get esContado => tipoPago != 'fiado';
  bool get esFiado => tipoPago == 'fiado';
  bool get anulada => estado == 'anulada';

  String get numeroFormateado =>
      numeroVenta != null ? '#${numeroVenta.toString().padLeft(4, '0')}' : '—';

  factory VentaModel.fromMap(Map<String, dynamic> map) {
    return VentaModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      clienteId: map['cliente_id'],
      usuarioId: map['usuario_id'],
      numeroVenta: map['numero_venta'],
      tipoPago: map['tipo_pago'] ?? 'efectivo',
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      itbis: (map['itbis'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      montoPagado: (map['monto_pagado'] ?? 0).toDouble(),
      cambio: (map['cambio'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'completada',
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['cliente_nombre'],
      detalles: (map['detalle_ventas'] as List<dynamic>? ?? [])
          .map((d) => DetalleVentaModel.fromMap(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'numero_venta': numeroVenta,
      'tipo_pago': tipoPago,
      'subtotal': subtotal,
      'descuento': descuento,
      'itbis': itbis,
      'total': total,
      'monto_pagado': montoPagado,
      'cambio': cambio,
      'estado': estado,
      'notas': notas,
    };
  }
}