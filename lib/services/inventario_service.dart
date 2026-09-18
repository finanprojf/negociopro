import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import '../utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class InventarioService {
  static const _uuid = Uuid();



  // ============================================================
  // CATEGORÍAS
  // ============================================================
  static Future<List<CategoriaModel>> getCategorias() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

  if (await SupabaseService.isOnlineAsync) {
      try {
        final res = await SupabaseService.client
            .from('categorias')
            .select()
            .eq('empresa_id', empresaId)
            .order('nombre');
        return res.map((m) => CategoriaModel.fromMap(m)).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar('categorias', empresaId, orderBy: 'nombre ASC');
    return local.map((m) => CategoriaModel.fromMap(m)).toList();
  }


  static Future<CategoriaModel?> crearCategoria(String nombre) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return null;
    final id = const Uuid().v4();
    final cat = CategoriaModel(id: id, empresaId: empresaId, nombre: nombre.trim());
    try {
      await SupabaseService.client.from('categorias').insert({
        'id': id,
        'empresa_id': empresaId,
        'nombre': cat.nombre,
        'color': cat.color,
      });
    } catch (_) {}
    await LocalDatabase.insertar('categorias', cat.toMap()..['id'] = id..['empresa_id'] = empresaId);
    return cat;
  }

  // ============================================================
  // PRODUCTOS
  // ============================================================
  static Future<List<ProductoModel>> getProductos({bool soloActivos = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    final local = await LocalDatabase.consultar('productos', empresaId,
        orderBy: 'nombre ASC');
    final productosLocal = local
        .where((m) => !soloActivos || m['activo'] == 1)
        .map((m) => ProductoModel.fromMap(m))
        .toList();

    if (await SupabaseService.isOnlineAsync) {
      try {
        var query = SupabaseService.client
            .from('productos')
            .select('*, categorias(nombre)')
            .eq('empresa_id', empresaId);
        if (soloActivos) query = query.eq('activo', true);
        final res = await query.order('nombre');

        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          if (m['categorias'] != null) {
            map['categoria_nombre'] = m['categorias']['nombre'];
          }
          map.remove('categorias');
          map['synced'] = 1;
          map['activo'] = m['activo'] == true ? 1 : 0;         // bool → int para SQLite
          map['es_elaborado'] = m['es_elaborado'] == true ? 1 : 0; // bool → int para SQLite
          try {
            await LocalDatabase.insertar('productos', map);
          } catch (_) {}
        }

        return res.map((m) {
          final map = Map<String, dynamic>.from(m);
          if (m['categorias'] != null) {
            map['categoria_nombre'] = m['categorias']['nombre'];
          }
          return ProductoModel.fromMap(map);
        }).toList();
      } catch (_) {}
    }

    return productosLocal;
  }

  static Future<bool> guardarProducto(ProductoModel producto,
      {bool esNuevo = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = esNuevo ? _uuid.v4() : producto.id;
    final map = {
      ...producto.toMap(),
      'id': id,
      'empresa_id': empresaId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };

   // Guardar local primero
    if (esNuevo) {
      await LocalDatabase.insertar('productos', map);
    } else {
      await LocalDatabase.actualizar('productos', map, 'id', id);
    }

    // Intentar sync online
    if (await SupabaseService.isOnlineAsync) {
      try {
        final dataOnline = {
          ...producto.toMap(),
          'id': id,
          'empresa_id': empresaId,
          'activo': producto.activo,              // bool para Supabase
          'es_elaborado': producto.esElaborado,   // bool para Supabase
        };
        if (esNuevo) {
          await SupabaseService.client.from('productos').insert(dataOnline);
        } else {
          await SupabaseService.client.from('productos')
              .update(dataOnline).eq('id', id);
        }
        await LocalDatabase.marcarSynced('productos', id);
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> actualizarStock(String productoId, double cantidad,
      {String tipo = 'ajuste'}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    await LocalDatabase.actualizar(
        'productos', {'stock_actual': cantidad, 'updated_at': DateTime.now().toIso8601String()},
        'id', productoId);

   if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client
            .from('productos')
            .update({'stock_actual': cantidad, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', productoId);
      } catch (_) {}
    }

    return true;
  }

  /// Sube la foto a Supabase Storage y devuelve la URL pública.
  /// Si falla, devuelve null (se sigue guardando sin foto pública).
  static Future<String?> uploadFoto(String archivoPath, String productoId) async {
    try {
      final file   = File(archivoPath);
      final ext    = archivoPath.split('.').last.toLowerCase();
      final bucket = AppConstants.bucketProductos;
      final key    = 'productos/$productoId.$ext';

      await SupabaseService.client.storage
          .from(bucket)
          .upload(key, file,
              fileOptions: const FileOptions(upsert: true));

      final url = SupabaseService.client.storage
          .from(bucket)
          .getPublicUrl(key);

      return url;
    } catch (_) {
      return null;
    }
  }
}