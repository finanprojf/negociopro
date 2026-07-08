class AppConstants {
  // Supabase — reemplazar con los datos reales cuando crees el proyecto
 static const String supabaseUrl = 'https://ljsjysphifhbyhhfxbyb.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxqc2p5c3BoaWZoYnloaGZ4YnliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2MDA1NzQsImV4cCI6MjA5ODE3NjU3NH0.RP9mpDSAiqSakBRvFY5AGYqFEo68JioUyvnvmlL6bV0';

  // App info
  static const String appName = 'NegocioPro';
  static const String appVersion = '1.0.0';
  static const String company = 'FinanPro Solutions';

  // Storage buckets
  static const String bucketLogos = 'negociopro-logos';
  static const String bucketProductos = 'negociopro-productos';
  static const String bucketGastos = 'negociopro-gastos';

  // Moneda por defecto
  static const String monedaDefault = 'DOP';
  static const String simboloDefault = 'RD\$';

  // Roles de usuario
  static const String rolAdmin = 'admin';
  static const String rolCajero = 'cajero';
  static const String rolInventario = 'inventario';

  // Planes de suscripción
  static const String planBasico = 'basico';
  static const String planPro = 'pro';
  static const String planEnterprise = 'enterprise';

  // SQLite
  static const String dbName = 'negociopro.db';
  static const int dbVersion = 2;
}