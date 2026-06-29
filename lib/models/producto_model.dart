class ProductoModel {
  final String id;
  final String empresaId;
  final String? categoriaId;
  final String nombre;
  final String? descripcion;
  final String? codigoBarras;
  final String? fotoUrl;
  final double precioCompra;
  final double precioVenta;
  final double stockActual;
  final double stockMinimo;
  final String unidad;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Campo local (no en Supabase) para nombre de categoría
  final String? categoriaNombre;

  ProductoModel({
    required this.id,
    required this.empresaId,
    this.categoriaId,
    required this.nombre,
    this.descripcion,
    this.codigoBarras,
    this.fotoUrl,
    this.precioCompra = 0,
    required this.precioVenta,
    this.stockActual = 0,
    this.stockMinimo = 5,
    this.unidad = 'unidad',
    this.activo = true,
    this.createdAt,
    this.updatedAt,
    this.categoriaNombre,
  });

  /// ¿Está por debajo del stock mínimo?
  bool get stockBajo => stockActual <= stockMinimo;

  /// ¿Sin stock?
  bool get sinStock => stockActual <= 0;

  /// Ganancia por unidad
  double get ganancia => precioVenta - precioCompra;

  /// Margen de ganancia en %
  double get margen => precioCompra > 0 ? (ganancia / precioCompra) * 100 : 0;

  factory ProductoModel.fromMap(Map<String, dynamic> map) {
    return ProductoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      categoriaId: map['categoria_id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      codigoBarras: map['codigo_barras'],
      fotoUrl: map['foto_url'],
      precioCompra: (map['precio_compra'] ?? 0).toDouble(),
      precioVenta: (map['precio_venta'] ?? 0).toDouble(),
      stockActual: (map['stock_actual'] ?? 0).toDouble(),
      stockMinimo: (map['stock_minimo'] ?? 5).toDouble(),
      unidad: map['unidad'] ?? 'unidad',
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      categoriaNombre: map['categoria_nombre'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'codigo_barras': codigoBarras,
      'foto_url': fotoUrl,
      'precio_compra': precioCompra,
      'precio_venta': precioVenta,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'unidad': unidad,
      'activo': activo,
    };
  }

  ProductoModel copyWith({
    String? categoriaId, String? nombre, String? descripcion,
    String? codigoBarras, String? fotoUrl, double? precioCompra,
    double? precioVenta, double? stockActual, double? stockMinimo,
    String? unidad, bool? activo,
  }) {
    return ProductoModel(
      id: id,
      empresaId: empresaId,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      unidad: unidad ?? this.unidad,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}