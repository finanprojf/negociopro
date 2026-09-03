import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class FidelizacionScreen extends StatefulWidget {
  const FidelizacionScreen({super.key});

  @override
  State<FidelizacionScreen> createState() => _FidelizacionScreenState();
}

class _FidelizacionScreenState extends State<FidelizacionScreen> {
  // Demo — TODO: cargar desde PuntosService
  final List<Map<String, dynamic>> _ranking = [
    {'nombre': 'Ana García', 'puntos': 310, 'compras': 24, 'gasto': 38500.0},
    {'nombre': 'María López', 'puntos': 120, 'compras': 12, 'gasto': 14800.0},
    {'nombre': 'Juan Pérez', 'puntos': 45, 'compras': 5, 'gasto': 5200.0},
    {'nombre': 'Carlos M.', 'puntos': 20, 'compras': 2, 'gasto': 2100.0},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fidelización')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildConfigCard(),
          const SizedBox(height: 20),
          _buildTituloSeccion('Ranking de clientes frecuentes'),
          const SizedBox(height: 12),
          ..._ranking.asMap().entries.map((e) =>
              _RankingTile(posicion: e.key + 1, data: e.value)),
          const SizedBox(height: 20),
          _buildTituloSeccion('Cómo funciona'),
          const SizedBox(height: 12),
          _buildComoFunciona(),
        ]),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.colorFidelizacion, AppColors.colorFidelizacion.withValues(alpha: 0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.star_rounded, color: Colors.white, size: 32),
        const SizedBox(height: 12),
        const Text('Programa de puntos',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text('${_ranking.length} clientes con puntos activos',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 16),
        Row(children: [
          _MiniStat('1 pto', 'por RD\$ 1'),
          const SizedBox(width: 20),
          _MiniStat('RD\$ 0.01', 'valor por punto'),
          const SizedBox(width: 20),
          _MiniStat('100 pts', 'mínimo canje'),
        ]),
      ]),
    );
  }

  Widget _buildTituloSeccion(String t) => Text(t,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _buildComoFunciona() {
    final pasos = [
      {'icono': Icons.shopping_cart_rounded, 'titulo': 'Cliente compra',
        'desc': 'Acumula 1 punto por cada RD\$ 1 en compras'},
      {'icono': Icons.savings_rounded, 'titulo': 'Acumula puntos',
        'desc': 'Los puntos no vencen por 365 días'},
      {'icono': Icons.redeem_rounded, 'titulo': 'Canjea descuentos',
        'desc': 'Desde 100 puntos puede canjear en su próxima compra'},
    ];

    return Column(children: pasos.map((p) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.colorFidelizacion.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(p['icono'] as IconData,
              color: AppColors.colorFidelizacion, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['titulo'] as String, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(p['desc'] as String, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 11, color: AppColors.textSecondary)),
        ])),
      ]),
    )).toList());
  }
}

class _MiniStat extends StatelessWidget {
  final String valor; final String label;
  const _MiniStat(this.valor, this.label);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(valor, style: const TextStyle(fontFamily: 'Poppins', fontSize: 16,
          fontWeight: FontWeight.w700, color: Colors.white)),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
          color: Colors.white.withValues(alpha: 0.75))),
    ],
  );
}

class _RankingTile extends StatelessWidget {
  final int posicion; final Map<String, dynamic> data;
  const _RankingTile({required this.posicion, required this.data});

  @override
  Widget build(BuildContext context) {
    Color medalColor;
    if (posicion == 1) medalColor = const Color(0xFFFFD700);
    else if (posicion == 2) medalColor = const Color(0xFFC0C0C0);
    else if (posicion == 3) medalColor = const Color(0xFFCD7F32);
    else medalColor = AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: posicion <= 3
            ? medalColor.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: posicion <= 3
              ? medalColor.withValues(alpha: 0.3) : AppColors.cardBorder,
        ),
      ),
      child: Row(children: [
        // Posición / medalla
        SizedBox(
          width: 32,
          child: posicion <= 3
              ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 26)
              : Text('#$posicion', style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
        ),
        const SizedBox(width: 12),
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.colorFidelizacion.withValues(alpha: 0.1),
          child: Text(data['nombre'].toString()[0],
              style: const TextStyle(fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700, color: AppColors.colorFidelizacion)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['nombre'] as String, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('${data['compras']} compras · ${AppFormatters.moneda(data['gasto'] as double)}',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 11, color: AppColors.textMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.colorFidelizacion.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${data['puntos']} pts',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                  fontWeight: FontWeight.w700, color: AppColors.colorFidelizacion)),
        ),
      ]),
    );
  }
}