import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import '../utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'local_database.dart';
import 'venta_service.dart';

class InventarioService {
  static const _uuid = Uuid();



  // ============================================================
  // CATEGORÍAS
  // ============================================================
  static Future<List<CategoriaModel>> getCategorias() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    final local = await LocalDatabase.consultar('categorias', empresaId, orderBy: 'nombre ASC');

    if (await SupabaseService.isOnlineAsync) {
      try {
        final res = await SupabaseService.client
            .from('categorias')
            .select()
            .eq('empresa_id', empresaId)
            .order('nombre');
        // Cachear en SQLite para uso offline
        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          map['synced'] = 1;
          try { await LocalDatabase.insertar('categorias', map); } catch (_) {}
        }
        // Incluir categorías locales pendientes (creadas offline) que no están en Supabase
        final idsOnline = res.map((m) => m['id'] as String).toSet();
        final pendientes = local.where((m) => !idsOnline.contains(m['id'] as String));
        final resultado = [
          ...res.map((m) => CategoriaModel.fromMap(m)),
          ...pendientes.map((m) => CategoriaModel.fromMap(m)),
        ];
        resultado.sort((a, b) => a.nombre.compareTo(b.nombre));
        return resultado;
      } catch (_) {}
    }

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

    final online = await SupabaseService.isOnlineAsync;
    if (online) {
      // Primero subir lo pendiente de ESTE teléfono, así la nube queda al día
      // y los dos teléfonos ven el mismo stock.
      try { await VentaService.sincronizarPendientes(); } catch (_) {}
      try { await _subirProductosPendientes(empresaId); } catch (_) {}
    }

    final local = await LocalDatabase.consultar('productos', empresaId,
        orderBy: 'nombre ASC');
    final productosLocal = local
        .where((m) => !soloActivos || m['activo'] == 1)
        .map((m) => ProductoModel.fromMap(m))
        .toList();

    if (online) {
      try {
        var query = SupabaseService.client
            .from('productos')
            .select('*, categorias(nombre)')
            .eq('empresa_id', empresaId);
        if (soloActivos) query = query.eq('activo', true);
        final res = await query.order('nombre');

        // Cargar ofertas activas de vitrina PRIMERO (para cachear con productos)
        Map<String, Map<String, dynamic>> ofertaMap = {};
        try {
          final vitrina = await SupabaseService.client
              .from('vitrina_productos')
              .select('producto_id, precio_oferta, descuento_porcentaje')
              .eq('empresa_id', empresaId);
          ofertaMap = {
            for (final v in vitrina)
              v['producto_id'] as String: v as Map<String, dynamic>
          };
        } catch (_) {}

        // IDs con cambios locales pendientes — no sobreescribir
        final idsPendientes = local
            .where((m) => m['synced'] == 0)
            .map((m) => m['id'] as String)
            .toSet();

        for (final m in res) {
          if (idsPendientes.contains(m['id'] as String?)) continue;
          final map = Map<String, dynamic>.from(m);
          map.remove('categorias');
          map.remove('categoria_nombre');
          map['synced'] = 1;
          map['activo'] = m['activo'] == true ? 1 : 0;
          map['es_elaborado'] = m['es_elaborado'] == true ? 1 : 0;
          // Cachear oferta en SQLite para disponibilidad offline
          final oferta = ofertaMap[m['id'] as String];
          map['precio_oferta']        = oferta?['precio_oferta'];
          map['descuento_porcentaje'] = oferta?['descuento_porcentaje'];
          try {
            await LocalDatabase.insertar('productos', map);
          } catch (_) {}
        }

        // Mapa de pendientes locales para que la lista use la versión local
        final localPendMap = Map.fromEntries(
          productosLocal
              .where((p) => idsPendientes.contains(p.id))
              .map((p) => MapEntry(p.id, p)),
        );

        final idsOnline = res.map((m) => m['id'] as String).toSet();
        final pendientesNoEnSupabase = productosLocal
            .where((p) => !idsOnline.contains(p.id))
            .toList();

        return [
          ...res.map((m) {
            final id = m['id'] as String;
            if (localPendMap.containsKey(id)) return localPendMap[id]!;
            final map = Map<String, dynamic>.from(m);
            if (m['categorias'] != null) {
              map['categoria_nombre'] = m['categorias']['nombre'];
            }
            final oferta = ofertaMap[id];
            map['precio_oferta']        = oferta?['precio_oferta'];
            map['descuento_porcentaje'] = oferta?['descuento_porcentaje'];
            return ProductoModel.fromMap(map);
          }),
          ...pendientesNoEnSupabase,
        ];
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
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
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
          'carta_disponible': producto.cartaDisponible, // bool para Supabase
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

  /// Sube a Supabase los productos que se quedaron sin subir (synced = 0).
  /// Antes nadie los subía y ese teléfono se quedaba con su stock para siempre.
  static Future<void> _subirProductosPendientes(String empresaId) async {
    final db = await LocalDatabase.database;
    final pendientes = await db.query('productos',
        where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
    for (final row in pendientes) {
      try {
        final p = ProductoModel.fromMap(row);
        await SupabaseService.client.from('productos').upsert({
          ...p.toMap(),
          'id': p.id,
          'empresa_id': empresaId,
          'activo': p.activo,
          'es_elaborado': p.esElaborado,
          'carta_disponible': p.cartaDisponible,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await LocalDatabase.marcarSynced('productos', p.id);
      } catch (e) {
        // Se reintenta la próxima vez
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // INVENTARIO QUE SE ARMA SOLO
  // Cada artículo que se vende, fía, aparta o entrega a mano queda
  // guardado como producto. La próxima vez ya aparece como sugerencia.
  // ══════════════════════════════════════════════════════════

  static String _normalizar(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Sugerencias mientras el usuario escribe (solo del teléfono, al instante)
  static Future<List<ProductoModel>> sugerencias(String texto, {int limite = 6}) async {
    final q = _normalizar(texto);
    if (q.isEmpty) return [];
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];
    final db = await LocalDatabase.database;
    final rows = await db.query('productos',
        where: 'empresa_id = ? AND activo = 1', whereArgs: [empresaId]);
    final lista = rows.map((m) => ProductoModel.fromMap(m))
        .where((p) => _normalizar(p.nombre).contains(q)).toList()
      ..sort((a, b) {
        // Primero los que EMPIEZAN con lo escrito
        final aEmp = _normalizar(a.nombre).startsWith(q) ? 0 : 1;
        final bEmp = _normalizar(b.nombre).startsWith(q) ? 0 : 1;
        return aEmp != bEmp ? aEmp - bEmp : a.nombre.compareTo(b.nombre);
      });
    return lista.take(limite).toList();
  }

  static Future<ProductoModel?> buscarPorNombre(String nombre) async {
    final q = _normalizar(nombre);
    if (q.isEmpty) return null;
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return null;
    final db = await LocalDatabase.database;
    final rows = await db.query('productos',
        where: 'empresa_id = ?', whereArgs: [empresaId]);
    for (final m in rows) {
      if (_normalizar(m['nombre'] as String? ?? '') == q) {
        return ProductoModel.fromMap(m);
      }
    }
    return null;
  }

  /// Devuelve el producto con ese nombre; si no existe, lo crea solo
  /// (sin control de cantidad, para no estorbar). Nunca lanza error.
  static Future<ProductoModel?> obtenerOCrear({
    required String nombre,
    required double precio,
    double costo = 0,
  }) async {
    try {
      final limpio = nombre.trim();
      if (limpio.isEmpty) return null;
      final existente = await buscarPorNombre(limpio);
      if (existente != null) return existente;

      final bonito = limpio[0].toUpperCase() + limpio.substring(1);
      await guardarProducto(ProductoModel(
        id: '',
        empresaId: '',
        nombre: bonito,
        precioVenta: precio > 0 ? precio : 0,
        precioCompra: costo > 0 ? costo : 0,
        stockActual: 0,
        stockMinimo: -1, // sin control de cantidad
      ));
      return await buscarPorNombre(limpio);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> actualizarStock(String productoId, double cantidad,
      {String tipo = 'ajuste'}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final ahora = DateTime.now().toUtc().toIso8601String();
    await LocalDatabase.actualizar(
        'productos', {'stock_actual': cantidad, 'updated_at': ahora, 'synced': 0},
        'id', productoId);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client
            .from('productos')
            .update({'stock_actual': cantidad, 'updated_at': ahora})
            .eq('id', productoId);
        await LocalDatabase.marcarSynced('productos', productoId);
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