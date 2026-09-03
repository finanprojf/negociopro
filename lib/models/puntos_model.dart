class PuntosModel {
  final String id;
  final String empresaId;
  final String clienteId;
  final String? ventaId;
  final String tipo; // ganado | canjeado | ajuste | vencido
  final int puntos;
  final String? descripcion;
  final DateTime? createdAt;

  PuntosModel({
    required this.id,
    required this.empresaId,
    required this.clienteId,
    this.ventaId,
    required this.tipo,
    required this.puntos,
    this.descripcion,
    this.createdAt,
  });

  bool get esGanado => tipo == 'ganado';
  bool get esCanjeado => tipo == 'canjeado';

  factory PuntosModel.fromMap(Map<String, dynamic> map) {
    return PuntosModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      clienteId: map['cliente_id'] ?? '',
      ventaId: map['venta_id'],
      tipo: map['tipo'] ?? 'ganado',
      puntos: map['puntos'] ?? 0,
      descripcion: map['descripcion'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'venta_id': ventaId,
      'tipo': tipo,
      'puntos': puntos,
      'descripcion': descripcion,
    };
  }
}