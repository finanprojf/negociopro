class ClienteModel {
  final String id;
  final String empresaId;
  final String nombre;
  final String? telefono;
  final String? cedula;
  final String? correo;
  final String? direccion;
  final String? fotoUrl;
  final String? notas;
  final int puntosFidelidad;
  final double limiteCredito;
  final bool activo;
  final DateTime? createdAt;

  // Campos calculados (joins desde Supabase)
  final double? saldoFiado;
  final int? totalCompras;

  ClienteModel({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.telefono,
    this.cedula,
    this.correo,
    this.direccion,
    this.fotoUrl,
    this.notas,
    this.puntosFidelidad = 0,
    this.limiteCredito = 0,
    this.activo = true,
    this.createdAt,
    this.saldoFiado,
    this.totalCompras,
  });

  bool get tieneDeuda => (saldoFiado ?? 0) > 0;
  bool get tienePuntos => puntosFidelidad > 0;

  /// Iniciales para el avatar
  String get iniciales {
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    return ClienteModel(
      id: map['id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      cedula: map['cedula'],
      correo: map['correo'],
      direccion: map['direccion'],
      fotoUrl: map['foto_url'],
      notas: map['notas'],
      puntosFidelidad: map['puntos_fidelidad'] ?? 0,
      limiteCredito: (map['limite_credito'] ?? 0).toDouble(),
activo: map['activo'] == true || map['activo'] == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      saldoFiado: map['saldo_fiado'] != null ? (map['saldo_fiado']).toDouble() : null,
      totalCompras: map['total_compras'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'nombre': nombre,
      'telefono': telefono,
      'cedula': cedula,
      'correo': correo,
      'direccion': direccion,
      'foto_url': fotoUrl,
      'notas': notas,
      'limite_credito': limiteCredito,
      'activo': activo,
    };
  }

  ClienteModel copyWith({
    String? nombre, String? telefono, String? cedula,
    String? correo, String? direccion, String? fotoUrl,
    String? notas, double? limiteCredito, bool? activo,
  }) {
    return ClienteModel(
      id: id,
      empresaId: empresaId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      cedula: cedula ?? this.cedula,
      correo: correo ?? this.correo,
      direccion: direccion ?? this.direccion,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      notas: notas ?? this.notas,
      puntosFidelidad: puntosFidelidad,
      limiteCredito: limiteCredito ?? this.limiteCredito,
      activo: activo ?? this.activo,
      createdAt: createdAt,
    );
  }
}