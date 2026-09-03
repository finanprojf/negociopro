import 'producto_model.dart';

class ApartadoModel {
  final String id;
  final String empresaId;
  final String clienteId;
  final String? usuarioId;
  final int? numeroApartado;
  final String descripcion;
  final double montoTotal;
  final double montoPagado;
  final double saldoPendiente;
  final DateTime? fechaEstimada;
  final String estado;
  final String? notas;
  final DateTime? createdAt;

  // Relaciones
  final String? clienteNombre;
  final String? clienteTelefono;
  final List<ApartadoProducto> productos;

  ApartadoModel({
    required this.id,
    required this.empresaId,
    required this.clienteId,
    this.usuarioId,
    this.numeroApartado,
    required this.descripcion,
    required this.montoTotal,
    this.montoPagado = 0,
    required this.saldoPendiente,
    this.fechaEstimada,
    this.estado = 'activo',
    this.notas,
    this.createdAt,
    this.clienteNombre,
    this.clienteTelefono,
    this.productos = const [],
  });

  double get porcentajePagado => montoTotal > 0 ? (montoPagado / montoTotal) : 0;
  bool get estaCompletado => estado == 'completado';
  bool get estaCancelado => estado == 'cancelado';
  bool get estaVencido => fechaEstimada != null &&
      fechaEstimada!.isBefore(DateTime.now()) && estado == 'activo';

  String get numeroFormateado =>
      numeroApartado != null ? 'APT-${numeroApartado.toString().padLeft(4, '0')}' : '—';

  factory ApartadoModel.fromMap(Map<String, dynamic> map) {
    return ApartadoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      usuarioId: map['usuario_id'],
      numeroApartado: map['numero_apartado'],
      descripcion: map['descripcion'] ?? '',
      montoTotal: (map['monto_total'] ?? 0).toDouble(),
      montoPagado: (map['monto_pagado'] ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      fechaEstimada: map['fecha_estimada'] != null ? DateTime.parse(map['fecha_estimada']) : null,
      estado: map['estado'] ?? 'activo',
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['clientes']?['nombre'],
      clienteTelefono: map['clientes']?['telefono'],
      productos: (map['apartado_productos'] as List<dynamic>? ?? [])
          .map((p) => ApartadoProducto.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'descripcion': descripcion,
      'monto_total': montoTotal,
      'monto_pagado': montoPagado,
      'saldo_pendiente': saldoPendiente,
      'fecha_estimada': fechaEstimada?.toIso8601String().split('T')[0],
      'estado': estado,
      'notas': notas,
    };
  }
}

class ApartadoProducto {
  final String id;
  final String apartadoId;
  final String? productoId;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  ApartadoProducto({
    required this.id,
    required this.apartadoId,
    this.productoId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ApartadoProducto.fromMap(Map<String, dynamic> map) {
    return ApartadoProducto(
      id: map['id'] ?? '',
      apartadoId: map['apartado_id'] ?? '',
      productoId: map['producto_id'],
      nombreProducto: map['nombre_producto'] ?? '',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }
}