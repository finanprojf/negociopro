class AbonoModel {
  final String id;
  final String empresaId;
  final String? fiadoId;
  final String? apartadoId;
  final String clienteId;
  final double monto;
  final String metodoPago;
  final String? notas;
  final String? usuarioId;
  final DateTime? createdAt;

  // Relaciones
  final String? clienteNombre;

  AbonoModel({
    required this.id,
    required this.empresaId,
    this.fiadoId,
    this.apartadoId,
    required this.clienteId,
    required this.monto,
    this.metodoPago = 'efectivo',
    this.notas,
    this.usuarioId,
    this.createdAt,
    this.clienteNombre,
  });

  factory AbonoModel.fromMap(Map<String, dynamic> map, {bool esApartado = false}) {
    return AbonoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      fiadoId: esApartado ? null : map['fiado_id'],
      apartadoId: esApartado ? map['apartado_id'] : null,
      clienteId: map['cliente_id'] ?? '',
      monto: (map['monto'] ?? 0).toDouble(),
      metodoPago: map['metodo_pago'] ?? 'efectivo',
      notas: map['notas'],
      usuarioId: map['usuario_id'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      clienteNombre: map['clientes']?['nombre'],
    );
  }

  Map<String, dynamic> toMap({bool esApartado = false}) {
    return {
      'empresa_id': empresaId,
      if (esApartado) 'apartado_id': apartadoId else 'fiado_id': fiadoId,
      'cliente_id': clienteId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'notas': notas,
    };
  }
}