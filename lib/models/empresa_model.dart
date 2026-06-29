class EmpresaModel {
  final String id;
  final String nombre;
  final String? telefono;
  final String? whatsapp;
  final String? correo;
  final String? direccion;
  final String moneda;
  final String? logoUrl;
  final String? lema;
  final String? mensajeRecibo;
  final DateTime? createdAt;

  EmpresaModel({
    required this.id,
    required this.nombre,
    this.telefono,
    this.whatsapp,
    this.correo,
    this.direccion,
    this.moneda = 'DOP',
    this.logoUrl,
    this.lema,
    this.mensajeRecibo,
    this.createdAt,
  });

  factory EmpresaModel.fromMap(Map<String, dynamic> map) {
    return EmpresaModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      whatsapp: map['whatsapp'],
      correo: map['correo'],
      direccion: map['direccion'],
      moneda: map['moneda'] ?? 'DOP',
      logoUrl: map['logo_url'],
      lema: map['lema'],
      mensajeRecibo: map['mensaje_recibo'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'whatsapp': whatsapp,
      'correo': correo,
      'direccion': direccion,
      'moneda': moneda,
      'logo_url': logoUrl,
      'lema': lema,
      'mensaje_recibo': mensajeRecibo,
    };
  }

  EmpresaModel copyWith({
    String? nombre, String? telefono, String? whatsapp,
    String? correo, String? direccion, String? moneda,
    String? logoUrl, String? lema, String? mensajeRecibo,
  }) {
    return EmpresaModel(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      whatsapp: whatsapp ?? this.whatsapp,
      correo: correo ?? this.correo,
      direccion: direccion ?? this.direccion,
      moneda: moneda ?? this.moneda,
      logoUrl: logoUrl ?? this.logoUrl,
      lema: lema ?? this.lema,
      mensajeRecibo: mensajeRecibo ?? this.mensajeRecibo,
      createdAt: createdAt,
    );
  }
}