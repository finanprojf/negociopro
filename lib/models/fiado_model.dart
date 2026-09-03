class FiadoModel {
  final String id;
  final String empresaId;
  final String clienteId;
  final String? ventaId;
  final double montoOriginal;
  final double saldoPendiente;
  final DateTime? fechaLimite;
  final String estado;
  final String? notas;
  final DateTime? createdAt;

  // Relaciones
  final String? clienteNombre;
  final String? clienteTelefono;

  FiadoModel({
    required this.id,
    required this.empresaId,
    required this.clienteId,
    this.ventaId,
    required this.montoOriginal,
    required this.saldoPendiente,
    this.fechaLimite,
    this.estado = 'activo',
    this.notas,
    this.createdAt,
    this.clienteNombre,
    this.clienteTelefono,
  });

  double get montoPagado => montoOriginal - saldoPendiente;
  double get porcentajePagado => montoOriginal > 0 ? (montoPagado / montoOriginal) : 0;
  bool get estaVencido => fechaLimite != null && fechaLimite!.isBefore(DateTime.now()) && estado == 'activo';
  bool get estaPagado => estado == 'pagado';

  factory FiadoModel.fromMap(Map<String, dynamic> map) {
    return FiadoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      ventaId: map['venta_id'],
      montoOriginal: (map['monto_original'] ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0).toDouble(),
      fechaLimite: map['fecha_limite'] != null ? DateTime.parse(map['fecha_limite']) : null,
      estado: map['estado'] ?? 'activo',
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['clientes']?['nombre'],
      clienteTelefono: map['clientes']?['telefono'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'venta_id': ventaId,
      'monto_original': montoOriginal,
      'saldo_pendiente': saldoPendiente,
      'fecha_limite': fechaLimite?.toIso8601String(),
      'estado': estado,
      'notas': notas,
    };
  }
}