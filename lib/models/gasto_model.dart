class GastoModel {
  final String id;
  final String empresaId;
  final String categoria;
  final String descripcion;
  final double monto;
  final String metodoPago;
  final DateTime fecha;
  final String? reciboUrl;
  final String? usuarioId;
  final String? notas;
  final DateTime? createdAt;

  GastoModel({
    required this.id,
    required this.empresaId,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    this.metodoPago = 'efectivo',
    required this.fecha,
    this.reciboUrl,
    this.usuarioId,
    this.notas,
    this.createdAt,
  });

  static const List<Map<String, String>> categorias = [
    {'id': 'produccion',   'label': 'Producción',        'icon': 'precision_manufacturing'},
    {'id': 'mercancia',    'label': 'Mercancía',        'icon': 'inventory_2'},
    {'id': 'empleados',    'label': 'Empleados',         'icon': 'people'},
    {'id': 'servicios',    'label': 'Servicios',         'icon': 'bolt'},
    {'id': 'alquiler',     'label': 'Alquiler',          'icon': 'home'},
    {'id': 'transporte',   'label': 'Transporte',        'icon': 'directions_car'},
    {'id': 'marketing',    'label': 'Marketing',         'icon': 'campaign'},
    {'id': 'mantenimiento','label': 'Mantenimiento',     'icon': 'build'},
    {'id': 'otros',        'label': 'Otros',             'icon': 'more_horiz'},
  ];

  String get categoriaLabel {
    return categorias.firstWhere(
      (c) => c['id'] == categoria,
      orElse: () => {'label': categoria},
    )['label'] ?? categoria;
  }

  factory GastoModel.fromMap(Map<String, dynamic> map) {
    return GastoModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      categoria: map['categoria'] ?? 'otros',
      descripcion: map['descripcion'] ?? '',
      monto: (map['monto'] ?? 0).toDouble(),
      metodoPago: map['metodo_pago'] ?? 'efectivo',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      reciboUrl: map['recibo_url'],
      usuarioId: map['usuario_id'],
      notas: map['notas'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'metodo_pago': metodoPago,
      'fecha': fecha.toIso8601String().split('T')[0],
      'recibo_url': reciboUrl,
      'notas': notas,
    };
  }
}