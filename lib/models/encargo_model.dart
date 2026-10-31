class EncargoModel {
  final String id;
  final String empresaId;
  final String? clienteId;
  final String descripcion;
  final double cantidad;
  final double precioEstimado;
  final double costoPedido;
  final String estado;
  final bool esListaPropia;
  final String? notas;
  final String? clienteNombre;
  final String? categoria;
  final DateTime? createdAt;

  EncargoModel({
    required this.id,
    required this.empresaId,
    this.clienteId,
    required this.descripcion,
    this.cantidad = 1,
    this.precioEstimado = 0,
    this.costoPedido = 0,
    this.estado = 'pendiente',
    this.esListaPropia = false,
    this.notas,
    this.clienteNombre,
    this.categoria,
    this.createdAt,
  });

  bool get estaPendiente => estado == 'pendiente';
  bool get llego => estado == 'llego';
  bool get entregado => estado == 'entregado';
  bool get comprado => estado == 'comprado';

  double get gananciaEstimada =>
      (precioEstimado > 0 && costoPedido > 0) ? precioEstimado - costoPedido : 0;

  factory EncargoModel.fromMap(Map<String, dynamic> map) {
    return EncargoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      clienteId: map['cliente_id'],
      descripcion: map['descripcion'] ?? '',
      cantidad: (map['cantidad'] ?? 1).toDouble(),
      precioEstimado: (map['precio_estimado'] ?? 0).toDouble(),
      costoPedido: (map['costo_pedido'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'pendiente',
      esListaPropia: map['es_lista_propia'] == true || map['es_lista_propia'] == 1,
      notas: map['notas'],
      clienteNombre: map['clientes']?['nombre'] ?? map['cliente_nombre'],
      categoria: map['categoria'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_estimado': precioEstimado,
      'costo_pedido': costoPedido,
      'estado': estado,
      'es_lista_propia': esListaPropia ? 1 : 0,
      'notas': notas,
      'categoria': categoria,
    };
  }
}
