import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../services/cliente_service.dart';
import '../../services/supabase_service.dart';

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
  File? _fotoFile;
  String? _fotoUrl;
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
      _fotoUrl = c.fotoUrl;
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: const Text('Tomar foto', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Elegir de galería', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (_fotoUrl != null || _fotoFile != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Quitar foto', style: TextStyle(fontFamily: 'Poppins',
                  color: AppColors.danger)),
              onTap: () {
                setState(() { _fotoFile = null; _fotoUrl = null; });
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final picked = await picker.pickImage(
          source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 90);
      if (picked == null) return;

      CroppedFile? cropped;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recortar foto',
              toolbarColor: AppColors.primary,
              statusBarColor: AppColors.primaryDark,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: AppColors.primary,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              hideBottomControls: false,
            ),
          ],
        );
      } catch (_) {
        // Si el recorte falla, usar la imagen original
        cropped = null;
      }
      // Si recortó, usar recorte; si no (canceló o falló), usar original
      setState(() => _fotoFile = File(cropped?.path ?? picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo seleccionar la foto: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<String?> _subirFoto(String clienteId) async {
    if (_fotoFile == null) return _fotoUrl;
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      final path = 'clientes/$empresaId/$clienteId.jpg';
      await SupabaseService.client.storage
          .from('fotos')
          .upload(path, _fotoFile!,
              fileOptions: FileOptions(upsert: true, contentType: 'image/jpeg'));
      return SupabaseService.client.storage.from('fotos').getPublicUrl(path);
    } catch (_) {
      return null;
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
      final clienteId = _esEdicion ? widget.cliente!.id : '';
      // Subir foto si hay una nueva seleccionada
      final fotoFinal = await _subirFoto(clienteId);

      await ClienteService.guardarCliente(
        ClienteModel(
          id: clienteId,
          empresaId: _esEdicion ? widget.cliente!.empresaId : '',
          nombre: _nombreCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
          cedula: _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
          correo: _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
          puntosFidelidad: _esEdicion ? widget.cliente!.puntosFidelidad : 0,
          fotoUrl: fotoFinal,
        ),
        esNuevo: !_esEdicion,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_esEdicion ? 'Cliente actualizado' : 'Cliente registrado'),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
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
              // Avatar con foto
              Center(
                child: GestureDetector(
                  onTap: _seleccionarFoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
                        backgroundImage: _fotoFile != null
                            ? FileImage(_fotoFile!) as ImageProvider
                            : (_fotoUrl != null ? NetworkImage(_fotoUrl!) : null),
                        child: (_fotoFile == null && _fotoUrl == null)
                            ? const Icon(Icons.person_rounded,
                                size: 50, color: AppColors.colorClientes)
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 17),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Toca para agregar foto',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                        color: AppColors.textMuted)),
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