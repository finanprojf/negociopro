class CierreDiaModel {
  final String id;
  final String empresaId;
  final DateTime fecha;
  final double totalVentas;
  final int cantidadVentas;
  final double totalGastos;
  final double ganancia;
  final double gananciaReal; // margen bruto real - gastos
  final double efectivoEsperado;
  final double efectivoContado;
  final double diferencia; // positivo = sobra, negativo = falta
  final String? notas;
  final int synced;
  final DateTime? createdAt;

  CierreDiaModel({
    required this.id,
    required this.empresaId,
    required this.fecha,
    required this.totalVentas,
    required this.cantidadVentas,
    required this.totalGastos,
    required this.ganancia,
    this.gananciaReal = 0,
    required this.efectivoEsperado,
    required this.efectivoContado,
    required this.diferencia,
    this.notas,
    this.synced = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresa_id': empresaId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'total_ventas': totalVentas,
        'cantidad_ventas': cantidadVentas,
        'total_gastos': totalGastos,
        'ganancia': ganancia,
        'ganancia_real': gananciaReal,
        'efectivo_esperado': efectivoEsperado,
        'efectivo_contado': efectivoContado,
        'diferencia': diferencia,
        'notas': notas,
        'synced': synced,
        'created_at': createdAt?.toIso8601String(),
      };

  factory CierreDiaModel.fromMap(Map<String, dynamic> m) => CierreDiaModel(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        totalVentas: (m['total_ventas'] as num).toDouble(),
        cantidadVentas: (m['cantidad_ventas'] as num).toInt(),
        totalGastos: (m['total_gastos'] as num).toDouble(),
        ganancia: (m['ganancia'] as num).toDouble(),
        gananciaReal: (m['ganancia_real'] as num? ?? 0).toDouble(),
        efectivoEsperado: (m['efectivo_esperado'] as num).toDouble(),
        efectivoContado: (m['efectivo_contado'] as num).toDouble(),
        diferencia: (m['diferencia'] as num).toDouble(),
        notas: m['notas'] as String?,
        synced: (m['synced'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
      );
}
