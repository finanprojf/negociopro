class DetalleVentaModel {
  final String id;
  final String ventaId;
  final String? productoId;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double descuento;
  final double subtotal;

  DetalleVentaModel({
    required this.id,
    required this.ventaId,
    this.productoId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0,
    required this.subtotal,
  });

  factory DetalleVentaModel.fromMap(Map<String, dynamic> map) {
    return DetalleVentaModel(
      id: map['id'] ?? '',
      ventaId: map['venta_id'] ?? '',
      productoId: map['producto_id'],
      nombreProducto: map['nombre_producto'] ?? '',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      precioUnitario: (map['precio_unitario'] ?? 0).toDouble(),
      descuento: (map['descuento'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'venta_id': ventaId,
      'producto_id': productoId,
      'nombre_producto': nombreProducto,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'descuento': descuento,
      'subtotal': subtotal,
    };
  }
}