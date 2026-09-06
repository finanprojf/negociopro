import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_colors.dart';

class ScannerScreen extends StatefulWidget {
  final String titulo;
  const ScannerScreen({super.key, this.titulo = 'Escanear código'});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _escaneado = false;
  bool _linterna = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (_escaneado) return;
    final valor = capture.barcodes.firstOrNull?.rawValue;
    if (valor != null && valor.isNotEmpty) {
      setState(() => _escaneado = true);
      _ctrl.stop();
      Navigator.pop(context, valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titulo,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(_linterna ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _linterna ? Colors.yellow : Colors.white),
            onPressed: () { _ctrl.toggleTorch(); setState(() => _linterna = !_linterna); },
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        Center(
          child: Container(
            width: 260, height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 60, left: 0, right: 0,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Apunta la cámara al código de barras del producto',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, null),
              icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
              label: const Text('Ingresar manualmente',
                  style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }
}
