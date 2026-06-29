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
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
      CREATE TABLE IF NOT EXISTS movimientos_puntos (
        id TEXT PRIMARY KEY, empresa_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL, venta_id TEXT,
        tipo TEXT NOT NULL, puntos INTEGER NOT NULL,
        descripcion TEXT, synced INTEGER DEFAULT 0, created_at TEXT
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // Aquí van los ALTER TABLE para futuras versiones
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
    return db.update(tabla, data, where: '$whereCol = ?', whereArgs: [whereVal]);
  }

  static Future<int> eliminar(String tabla,
      String whereCol, String whereVal) async {
    final db = await database;
    return db.delete(tabla, where: '$whereCol = ?', whereArgs: [whereVal]);
  }

  static Future<List<Map<String, dynamic>>> consultar(
      String tabla, String empresaId, {String? orderBy}) async {
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
    await db.update(tabla, {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> cerrar() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}