import 'package:uuid/uuid.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
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

    if (SupabaseService.isOnline) {
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

  // ============================================================
  // PRODUCTOS
  // ============================================================
  static Future<List<ProductoModel>> getProductos({bool soloActivos = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    if (SupabaseService.isOnline) {
      try {
        var query = SupabaseService.client
            .from('productos')
            .select('*, categorias(nombre)')
            .eq('empresa_id', empresaId);
        if (soloActivos) query = query.eq('activo', true);
        final res = await query.order('nombre');
        return res.map((m) {
          final map = Map<String, dynamic>.from(m);
          if (m['categorias'] != null) {
            map['categoria_nombre'] = m['categorias']['nombre'];
          }
          return ProductoModel.fromMap(map);
        }).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar('productos', empresaId, orderBy: 'nombre ASC');
    return local
        .where((m) => !soloActivos || m['activo'] == 1)
        .map((m) => ProductoModel.fromMap(m))
        .toList();
  }

  static Future<List<ProductoModel>> getProductosBajoStock() async {
    final todos = await getProductos();
    return todos.where((p) => p.stockBajo).toList();
  }

 static Future<bool> guardarProducto(ProductoModel producto,
      {bool esNuevo = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    print('💾 guardarProducto empresaId: $empresaId');
    print('👤 userId: ${SupabaseService.userId}');
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
    await LocalDatabase.insertar('productos', map);

    // Intentar sync online
  if (SupabaseService.isOnline) {
      try {
        final dataOnline = {
          ...producto.toMap(),
          'id': id,
          'empresa_id': empresaId,
        };
        await SupabaseService.client.from('productos').insert(dataOnline);
        await LocalDatabase.marcarSynced('productos', id);
        print('✅ Producto guardado en Supabase');
      } catch (e) {
        print('❌ Error guardando producto: ${e.toString()}');
      }
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

    if (SupabaseService.isOnline) {
      try {
        await SupabaseService.client
            .from('productos')
            .update({'stock_actual': cantidad, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', productoId);
      } catch (_) {}
    }

    return true;
  }
}