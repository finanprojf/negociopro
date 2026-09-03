class CategoriaModel {
  final String id;
  final String empresaId;
  final String nombre;
  final String color;
  final String? icono;
  final DateTime? createdAt;

  CategoriaModel({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.color = '#0F7B5B',
    this.icono,
    this.createdAt,
  });

  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      nombre: map['nombre'] ?? '',
      color: map['color'] ?? '#0F7B5B',
      icono: map['icono'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'nombre': nombre,
      'color': color,
      'icono': icono,
    };
  }
}