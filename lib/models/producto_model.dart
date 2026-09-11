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

  // ── Producto elaborado (jugos, comida preparada, etc.) ──────
  final bool esElaborado;
  final double costoProduccion;   // total gastado en ingredientes/insumos
  final double unidadesProducidas; // cuántas unidades salieron de esa inversión

  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.esElaborado = false,
    this.costoProduccion = 0,
    this.unidadesProducidas = 1,
    this.createdAt,
    this.updatedAt,
    this.categoriaNombre,
  });

  // ── Getters de contabilidad ─────────────────────────────────

  /// Costo real por unidad
  double get costoUnitario {
    if (esElaborado) {
      final u = unidadesProducidas > 0 ? unidadesProducidas : 1;
      return costoProduccion / u;
    }
    return precioCompra;
  }

  /// Ganancia por unidad vendida
  double get ganancia => precioVenta - costoUnitario;

  /// Margen de ganancia en %
  double get margen => costoUnitario > 0 ? (ganancia / costoUnitario) * 100 : 0;

  /// ¿Precio de venta cubre el costo?
  bool get precioRentable => ganancia >= 0;

  bool get stockBajo => stockActual <= stockMinimo;
  bool get sinStock  => stockActual <= 0;

  // ── Precios sugeridos para producto elaborado ───────────────
  double get precioSugerido50  => costoUnitario * 1.50;
  double get precioSugerido100 => costoUnitario * 2.00;
  double get precioSugerido150 => costoUnitario * 2.50;

  factory ProductoModel.fromMap(Map<String, dynamic> map) => ProductoModel(
        id:                map['id'] ?? '',
        empresaId:         map['empresa_id'] ?? '',
        categoriaId:       map['categoria_id'],
        nombre:            map['nombre'] ?? '',
        descripcion:       map['descripcion'],
        codigoBarras:      map['codigo_barras'],
        fotoUrl:           map['foto_url'],
        precioCompra:      (map['precio_compra'] ?? 0).toDouble(),
        precioVenta:       (map['precio_venta'] ?? 0).toDouble(),
        stockActual:       (map['stock_actual'] ?? 0).toDouble(),
        stockMinimo:       (map['stock_minimo'] ?? 5).toDouble(),
        unidad:            map['unidad'] ?? 'unidad',
        activo:            map['activo'] == true || map['activo'] == 1,
        esElaborado:       map['es_elaborado'] == true || map['es_elaborado'] == 1,
        costoProduccion:   (map['costo_produccion'] ?? 0).toDouble(),
        unidadesProducidas:(map['unidades_producidas'] ?? 1).toDouble(),
        createdAt:  map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
        updatedAt:  map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
        categoriaNombre: map['categoria_nombre'],
      );

  Map<String, dynamic> toMap() => {
        'empresa_id':         empresaId,
        'categoria_id':       categoriaId,
        'nombre':             nombre,
        'descripcion':        descripcion,
        'codigo_barras':      codigoBarras,
        'foto_url':           fotoUrl,
        'precio_compra':      precioCompra,
        'precio_venta':       precioVenta,
        'stock_actual':       stockActual,
        'stock_minimo':       stockMinimo,
        'unidad':             unidad,
        'activo':             activo ? 1 : 0,    // int para SQLite
        'es_elaborado':       esElaborado ? 1 : 0,
        'costo_produccion':   costoProduccion,
        'unidades_producidas':unidadesProducidas,
      };

  ProductoModel copyWith({
    String? categoriaId, String? nombre, String? descripcion,
    String? codigoBarras, String? fotoUrl, double? precioCompra,
    double? precioVenta, double? stockActual, double? stockMinimo,
    String? unidad, bool? activo, bool? esElaborado,
    double? costoProduccion, double? unidadesProducidas,
  }) => ProductoModel(
        id:                id,
        empresaId:         empresaId,
        categoriaId:       categoriaId       ?? this.categoriaId,
        nombre:            nombre             ?? this.nombre,
        descripcion:       descripcion        ?? this.descripcion,
        codigoBarras:      codigoBarras       ?? this.codigoBarras,
        fotoUrl:           fotoUrl            ?? this.fotoUrl,
        precioCompra:      precioCompra       ?? this.precioCompra,
        precioVenta:       precioVenta        ?? this.precioVenta,
        stockActual:       stockActual        ?? this.stockActual,
        stockMinimo:       stockMinimo        ?? this.stockMinimo,
        unidad:            unidad             ?? this.unidad,
        activo:            activo             ?? this.activo,
        esElaborado:       esElaborado        ?? this.esElaborado,
        costoProduccion:   costoProduccion    ?? this.costoProduccion,
        unidadesProducidas:unidadesProducidas ?? this.unidadesProducidas,
        createdAt:         createdAt,
        updatedAt:         updatedAt,
      );
}
