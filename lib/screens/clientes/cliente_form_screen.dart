import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../services/cliente_service.dart';
import '../../models/cliente_model.dart';
class ClienteFormScreen extends StatefulWidget {
  final ClienteModel? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _loading = false;
  bool get _esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final c = widget.cliente!;
      _nombreCtrl.text = c.nombre;
      _telefonoCtrl.text = c.telefono ?? '';
      _cedulaCtrl.text = c.cedula ?? '';
      _correoCtrl.text = c.correo ?? '';
      _direccionCtrl.text = c.direccion ?? '';
      _notasCtrl.text = c.notas ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _telefonoCtrl.dispose(); _cedulaCtrl.dispose();
    _correoCtrl.dispose(); _direccionCtrl.dispose(); _notasCtrl.dispose();
    super.dispose();
  }

Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ClienteService.guardarCliente(ClienteModel(
        id: '',
        empresaId: '',
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        cedula: _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
        correo: _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      ));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cliente registrado'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      print('❌ ERROR CLIENTE: ${e.toString()}');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }
   

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_esEdicion ? 'Editar cliente' : 'Nuevo cliente')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
                      child: const Icon(Icons.person_rounded,
                          size: 44, color: AppColors.colorClientes),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 30, height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _seccion('Información personal'),
              const SizedBox(height: 12),
              _campo(_nombreCtrl, 'Nombre completo *', Icons.person_outline,
                  requerido: true),
              const SizedBox(height: 12),
              _campo(_telefonoCtrl, 'Teléfono', Icons.phone_outlined,
                  tipo: TextInputType.phone),
              const SizedBox(height: 12),
              _campo(_cedulaCtrl, 'Cédula', Icons.badge_outlined),
              const SizedBox(height: 12),
              _campo(_correoCtrl, 'Correo electrónico', Icons.email_outlined,
                  tipo: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _campo(_direccionCtrl, 'Dirección', Icons.location_on_outlined),
              const SizedBox(height: 20),
              _seccion('Notas internas'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Notas sobre este cliente (opcional)...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _guardar,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(_esEdicion ? 'Guardar cambios' : 'Registrar cliente',
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccion(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {TextInputType tipo = TextInputType.text, bool requerido = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      ),
      validator: requerido
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }
}