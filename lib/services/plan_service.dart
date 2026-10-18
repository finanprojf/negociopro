import 'supabase_service.dart';

/// Niveles de plan de NegocioPro
enum NivelPlan { trial, basico, pro, desconocido }

class PlanService {
  static NivelPlan? _cache;

  /// true  → 'pro' | 'activo' | 'trial'  (acceso completo)
  /// false → 'basico' o sin datos
  static bool get esPro {
    final n = _cache ?? NivelPlan.desconocido;
    return n == NivelPlan.pro || n == NivelPlan.trial || n == NivelPlan.desconocido;
  }

  static NivelPlan get nivel => _cache ?? NivelPlan.desconocido;

  /// Carga el plan desde Supabase y lo cachea en memoria.
  /// Llama esto al inicio de sesión (dashboard o AuthWrapper).
  static Future<NivelPlan> cargar() async {
    try {
      final sus = await SupabaseService.getSuscripcion();
      final raw = sus?['plan_activo'] as String? ?? '';
      _cache = _parsear(raw);
    } catch (_) {
      _cache = NivelPlan.desconocido;
    }
    return _cache!;
  }

  static void limpiar() => _cache = null;

  static NivelPlan _parsear(String raw) {
    switch (raw) {
      case 'pro':    return NivelPlan.pro;
      case 'basico': return NivelPlan.basico;
      case 'trial':  return NivelPlan.trial;
      case 'activo': return NivelPlan.pro; // legado → pro
      default:       return NivelPlan.desconocido;
    }
  }
}
