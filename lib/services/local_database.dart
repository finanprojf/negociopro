import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class LocalDatabase {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // Optimizaciones de rendimiento SQLite (con try/catch por seguridad)
    try { await db.execute('PRAGMA journal_mode = WAL'); } catch (_) {}
    try { await db.execute('PRAGMA cache_size = -4000'); } catch (_) {}
    try { await db.execute('PRAGMA synchronous = NORMAL'); } catch (_) {}
    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas (
        id TEXT PRIMARY KEY, nombre TEXT NOT NULL,
        telefono TEXT, whatsapp TEXT, correo TEXT, direccion TEXT,
        moneda TEXT DEFAULT 'DOP', logo_url TEXT, lema TEXT,
        mensaje_recibo TEXT, synced INTEGER DEFAULT 0,
        created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        nombre TEXT NOT NULL, color TEXT DEFAULT '#0F7B5B',
        icono TEXT, synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        categoria_id TEXT, nombre TEXT NOT NULL,
        descripcion TEXT, codigo_barras TEXT, foto_url TEXT,
        precio_compra REAL DEFAULT 0, precio_venta REAL NOT NULL,
        stock_actual REAL DEFAULT 0, stock_minimo REAL DEFAULT 5,
        unidad TEXT DEFAULT 'unidad', activo INTEGER DEFAULT 1,
        es_elaborado INTEGER DEFAULT 0,
        costo_produccion REAL DEFAULT 0,
        unidades_producidas REAL DEFAULT 1,
        synced INTEGER DEFAULT 0, created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        nombre TEXT NOT NULL, telefono TEXT, cedula TEXT,
        correo TEXT, direccion TEXT, foto_url TEXT, notas TEXT,
        puntos_fidelidad INTEGER DEFAULT 0,
        limite_credito REAL DEFAULT 0, activo INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0, created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT, usuario_id TEXT, numero_venta INTEGER,
        tipo_pago TEXT DEFAULT 'efectivo',
        subtotal REAL DEFAULT 0, descuento REAL DEFAULT 0,
        itbis REAL DEFAULT 0, total REAL NOT NULL,
        monto_pagado REAL DEFAULT 0, cambio REAL DEFAULT 0,
        estado TEXT DEFAULT 'completada', notas TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS detalle_ventas (
        id TEXT PRIMARY KEY, venta_id TEXT NOT NULL,
        producto_id TEXT, nombre_producto TEXT NOT NULL,
        cantidad REAL NOT NULL, precio_unitario REAL NOT NULL,
        descuento REAL DEFAULT 0, subtotal REAL NOT NULL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fiados (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL, venta_id TEXT,
        monto_original REAL NOT NULL, saldo_pendiente REAL NOT NULL,
        fecha_limite TEXT, estado TEXT DEFAULT 'activo', notas TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS abonos_fiado (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        fiado_id TEXT NOT NULL, cliente_id TEXT NOT NULL,
        monto REAL NOT NULL, metodo_pago TEXT DEFAULT 'efectivo',
        notas TEXT, usuario_id TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS apartados (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL, usuario_id TEXT,
        numero_apartado INTEGER, descripcion TEXT NOT NULL,
        monto_total REAL NOT NULL, monto_pagado REAL DEFAULT 0,
        saldo_pendiente REAL NOT NULL, fecha_estimada TEXT,
        estado TEXT DEFAULT 'activo', notas TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS abonos_apartado (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        apartado_id TEXT NOT NULL, cliente_id TEXT NOT NULL,
        monto REAL NOT NULL, metodo_pago TEXT DEFAULT 'efectivo',
        notas TEXT, usuario_id TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gastos (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        categoria TEXT NOT NULL, descripcion TEXT NOT NULL,
        monto REAL NOT NULL, metodo_pago TEXT DEFAULT 'efectivo',
        fecha TEXT, recibo_url TEXT, notas TEXT, usuario_id TEXT,
        synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS encargos (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT, descripcion TEXT NOT NULL,
        cantidad REAL DEFAULT 1, precio_estimado REAL DEFAULT 0,
        estado TEXT DEFAULT 'pendiente',
        es_lista_propia INTEGER DEFAULT 0,
        notas TEXT, synced INTEGER DEFAULT 0,
        created_at TEXT, updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_puntos (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL, venta_id TEXT,
        tipo TEXT NOT NULL, puntos INTEGER NOT NULL,
        descripcion TEXT, synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cierres_dia (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        total_ventas REAL DEFAULT 0, cantidad_ventas INTEGER DEFAULT 0,
        total_gastos REAL DEFAULT 0, ganancia REAL DEFAULT 0,
        ganancia_real REAL DEFAULT 0,
        efectivo_esperado REAL DEFAULT 0, efectivo_contado REAL DEFAULT 0,
        diferencia REAL DEFAULT 0,
        notas TEXT, synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recordatorios (
        id TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        titulo TEXT NOT NULL,
        cliente_id TEXT,
        cliente_nombre TEXT,
        fecha TEXT NOT NULL,
        hora TEXT,
        completado INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Índices para consultas rápidas por empresa y fecha
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_empresa ON productos(empresa_id, activo)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_empresa_fecha ON ventas(empresa_id, created_at)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_detalle_venta ON detalle_ventas(venta_id)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gastos_empresa_fecha ON gastos(empresa_id, created_at)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_fiados_empresa ON fiados(empresa_id, estado)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_empresa ON clientes(empresa_id, activo)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_abonos_fiado ON abonos_fiado(fiado_id)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_abonos_apartado ON abonos_apartado(apartado_id)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_apartados_empresa ON apartados(empresa_id, estado)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cierres_empresa_fecha ON cierres_dia(empresa_id, fecha)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_synced ON ventas(synced)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_recordatorios_empresa_fecha ON recordatorios(empresa_id, fecha)'); } catch (_) {}
  }

  // Migraciones por versión — agregar aquí cuando suba dbVersion
  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // Siempre crear índices si no existen — cada uno con try/catch para no bloquear
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_empresa ON productos(empresa_id, activo)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_empresa_fecha ON ventas(empresa_id, created_at)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_detalle_venta ON detalle_ventas(venta_id)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gastos_empresa_fecha ON gastos(empresa_id, created_at)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_fiados_empresa ON fiados(empresa_id, estado)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_empresa ON clientes(empresa_id, activo)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cierres_empresa_fecha ON cierres_dia(empresa_id, fecha)'); } catch (_) {}
    // v1 → v2: encargos ya está en _onCreate desde v2
    if (oldV < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recordatorios (
            id TEXT PRIMARY KEY,
            empresa_id TEXT NOT NULL,
            titulo TEXT NOT NULL,
            cliente_id TEXT,
            cliente_nombre TEXT,
            fecha TEXT NOT NULL,
            hora TEXT,
            completado INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_recordatorios_empresa_fecha ON recordatorios(empresa_id, fecha)'); } catch (_) {}
    }
    if (oldV < 7) {
      try { await db.execute('ALTER TABLE cierres_dia ADD COLUMN ganancia_real REAL DEFAULT 0'); } catch (_) {}
    }
    if (oldV < 5) {
      try { await db.execute('ALTER TABLE cierres_dia ADD COLUMN ganancia_real REAL DEFAULT 0'); } catch (_) {}
    }
    if (oldV < 4) {
      try { await db.execute('ALTER TABLE productos ADD COLUMN es_elaborado INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE productos ADD COLUMN costo_produccion REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE productos ADD COLUMN unidades_producidas REAL DEFAULT 1'); } catch (_) {}
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cierres_dia (
          id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
          fecha TEXT NOT NULL,
          total_ventas REAL DEFAULT 0, cantidad_ventas INTEGER DEFAULT 0,
          total_gastos REAL DEFAULT 0, ganancia REAL DEFAULT 0,
          efectivo_esperado REAL DEFAULT 0, efectivo_contado REAL DEFAULT 0,
          diferencia REAL DEFAULT 0,
          notas TEXT, synced INTEGER DEFAULT 0, created_at TEXT
        )
      ''');
    }
  }


  // ============================================================
  // HELPERS GENÉRICOS
  // ============================================================

  static Future<int> insertar(String tabla, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(tabla, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> actualizar(String tabla, Map<String, dynamic> data,
      String whereCol, String whereVal) async {
    final db = await database;
    return db.update(tabla, data,
        where: '$whereCol = ?', whereArgs: [whereVal]);
  }

  static Future<int> eliminar(
      String tabla, String whereCol, String whereVal) async {
    final db = await database;
    return db.delete(tabla, where: '$whereCol = ?', whereArgs: [whereVal]);
  }

  static Future<List<Map<String, dynamic>>> consultar(
      String tabla, String empresaId,
      {String? orderBy}) async {
    final db = await database;
    return db.query(tabla,
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
        orderBy: orderBy ?? 'created_at DESC');
  }

  static Future<List<Map<String, dynamic>>> consultarPendientesSync(
      String tabla) async {
    final db = await database;
    return db.query(tabla, where: 'synced = ?', whereArgs: [0]);
  }

  static Future<void> marcarSynced(String tabla, String id) async {
    final db = await database;
    await db.update(tabla, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> cerrar() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
