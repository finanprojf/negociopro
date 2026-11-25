import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/producto_model.dart';
import '../services/inventario_service.dart';
import '../theme/app_palette.dart';
import '../utils/formatters.dart';

/// Campo para escribir un artículo que SUGIERE los productos ya guardados.
/// Así "Nevera" vendida una vez aparece sola la próxima vez, con su precio.
class CampoArticulo extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final ValueChanged<ProductoModel> onSeleccionado;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const CampoArticulo({
    super.key,
    required this.controller,
    required this.decoration,
    required this.onSeleccionado,
    this.style,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<CampoArticulo> createState() => _CampoArticuloState();
}

class _CampoArticuloState extends State<CampoArticulo> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return RawAutocomplete<ProductoModel>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (p) => p.nombre,
      optionsBuilder: (value) async {
        if (value.text.trim().length < 2) return const <ProductoModel>[];
        return InventarioService.sugerencias(value.text);
      },
      onSelected: widget.onSeleccionado,
      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
        controller: ctrl,
        focusNode: focus,
        autofocus: widget.autofocus,
        textCapitalization: TextCapitalization.sentences,
        style: widget.style,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
        onSubmitted: (_) => onSubmit(),
      ),
      optionsViewBuilder: (ctx, onSelect, opciones) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          color: pal.surface,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: opciones.map((p) => InkWell(
                onTap: () => onSelect(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: pal.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600,
                            color: pal.textPrimary))),
                    if (p.precioVenta > 0)
                      Text(AppFormatters.moneda(p.precioVenta),
                          style: GoogleFonts.poppins(fontSize: 12, color: pal.primary,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
