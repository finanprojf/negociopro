import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class ImpresoraScreen extends StatefulWidget {
  const ImpresoraScreen({super.key});
  @override
  State<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends State<ImpresoraScreen> {
  List<BluetoothInfo> _impresoras = [];
  String? _macGuardada;
  String? _nombreGuardado;
  bool _cargando = true;
  bool _probando = false;
  bool _btApagado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _macGuardada    = prefs.getString('printer_mac');
      _nombreGuardado = prefs.getString('printer_name');

      // Solicitar permisos Bluetooth en runtime (Android 12+)
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();

      // Verificar que BT está habilitado
      final btOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btOn) {
        setState(() { _impresoras = []; _cargando = false; _btApagado = true; });
        return;
      }
      setState(() => _btApagado = false);
      final lista = await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 6), onTimeout: () => []);
      setState(() { _impresoras = lista; });
    } catch (_) {}
    setState(() => _cargando = false);
  }

  Future<void> _seleccionar(BluetoothInfo imp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_mac',    imp.macAdress);
    await prefs.setString('printer_name', imp.name);
    setState(() {
      _macGuardada    = imp.macAdress;
      _nombreGuardado = imp.name;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Impresora "${imp.name}" guardada'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _probar() async {
    if (_macGuardada == null) return;
    setState(() => _probando = true);
    try {
      final conectado = await PrintBluetoothThermal.connect(
          macPrinterAddress: _macGuardada!);
      if (!conectado) throw Exception('No se pudo conectar');
      final linea = '================================\n';
      final texto = '$linea'
          '       PRUEBA DE IMPRESION      \n'
          '$linea'
          'Impresora: $_nombreGuardado\n'
          'Sistema: NegocioPro\n'
          '$linea'
          '  Si ves esto, funciona bien!  \n'
          '$linea'
          '\n\n\n';
      final bytes = texto.codeUnits.map((c) => c > 255 ? 63 : c).toList();
      await PrintBluetoothThermal.writeBytes(bytes);
      await Future.delayed(const Duration(milliseconds: 300));
      await PrintBluetoothThermal.disconnect;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Impresión de prueba enviada'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    setState(() => _probando = false);
  }

  Future<void> _desvincular() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_mac');
    await prefs.remove('printer_name');
    setState(() { _macGuardada = null; _nombreGuardado = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impresora desvinculada'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Impresora Térmica',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Impresora actual ──────────────────────────
                if (_macGuardada != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.print_rounded,
                              color: AppColors.success, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Impresora conectada',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12, color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                            Text(_nombreGuardado ?? '',
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(_macGuardada ?? '',
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 11, color: AppColors.textMuted)),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: _probando ? null : _probar,
                          icon: _probando
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.print_outlined, size: 18),
                          label: Text(_probando ? 'Probando...' : 'Imprimir prueba',
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: BorderSide(color: AppColors.success.withValues(alpha: 0.5))),
                        )),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _desvincular,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4))),
                          child: const Text('Desvincular',
                              style: TextStyle(fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Lista de dispositivos vinculados ──────────
                const Text('Dispositivos Bluetooth vinculados',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                const Text(
                    'Vincula la impresora en Ajustes → Bluetooth del teléfono primero, luego selecciónala aquí.',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 12),

                if (_btApagado)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(children: [
                      Icon(Icons.bluetooth_disabled_rounded,
                          size: 48, color: AppColors.danger.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      const Text('Bluetooth apagado',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                      const SizedBox(height: 6),
                      const Text(
                          'Activa el Bluetooth en tu teléfono y toca el botón ↻ para actualizar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  )
                else if (_impresoras.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(children: [
                      Icon(Icons.bluetooth_disabled_rounded,
                          size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text('No hay dispositivos Bluetooth vinculados',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      const Text(
                          'Ve a Ajustes → Bluetooth en tu teléfono, activa la impresora y vincúlala. Luego regresa aquí y toca ↻.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  )
                else
                  ...(_impresoras.map((imp) {
                    final esActual = imp.macAdress == _macGuardada;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: esActual
                            ? AppColors.success.withValues(alpha: 0.06)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: esActual
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            esActual ? Icons.print_rounded : Icons.print_outlined,
                            color: esActual ? AppColors.success : AppColors.textSecondary,
                          ),
                          title: Text(imp.name,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 14)),
                          subtitle: Text(imp.macAdress,
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontSize: 11, color: AppColors.textMuted)),
                          trailing: esActual
                              ? const Chip(
                                  label: Text('Activa',
                                      style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 11, color: AppColors.success,
                                          fontWeight: FontWeight.w600)),
                                  backgroundColor: Color(0x1A4CAF50),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                )
                              : ElevatedButton(
                                  onPressed: () => _seleccionar(imp),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8)),
                                  child: const Text('Usar',
                                      style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                        ),
                      ),
                    );
                  })),
              ],
            ),
    );
  }
}
