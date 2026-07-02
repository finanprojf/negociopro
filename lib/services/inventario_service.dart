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

  // ============================================================
  // PRODUCTOS
  // ============================================================
  static Future<List<ProductoModel>> getProductos({bool soloActivos = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

 final local = await LocalDatabase.consultar('productos', empresaId, 
        orderBy: 'nombre ASC');
    print('📦 Productos en SQLite: ${local.length}');
    print('🌐 Online: ${await SupabaseService.isOnlineAsync}');
   print('📋 Primer producto local: ${local.isNotEmpty ? local.first : 'vacío'}');
    final productosLocal = local
        .where((m) => !soloActivos || m['activo'] == 1)
        .map((m) => ProductoModel.fromMap(m))
        .toList();

  // Si hay internet, traer de Supabase y actualizar local
    if (await SupabaseService.isOnlineAsync) {
      try {
        var query = SupabaseService.client
            .from('productos')
            .select('*, categorias(nombre)')
            .eq('empresa_id', empresaId);
        if (soloActivos) query = query.eq('activo', true);
        final res = await query.order('nombre');
        
      // Guardar en local
        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          if (m['categorias'] != null) {
            map['categoria_nombre'] = m['categorias']['nombre'];
          }
          map.remove('categorias');
          map['synced'] = 1;
          try {
            await LocalDatabase.insertar('productos', map);
          } catch (e) {
            print('❌ Error guardando producto local: $e');
          }
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

   // Si llegó aquí es porque no hay internet o falló Supabase
    return productosLocal;
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
        };
        if (esNuevo) {
          await SupabaseService.client.from('productos').insert(dataOnline);
        } else {
          await SupabaseService.client.from('productos')
              .update(dataOnline).eq('id', id);
        }
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
}