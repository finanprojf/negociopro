import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Niveles de plan de NegocioPro
enum NivelPlan { trial, basico, pro, desconocido }

class PlanService {
  static NivelPlan? _cache;
  static int? _diasRestantes; // días que quedan en cualquier plan (null = sin fecha límite)

  static const _kPlanActivo = 'cached_plan_activo';
  static const _kVence      = 'cached_suscripcion_vence';

  /// Días restantes del trial (null si no es trial activo)
  static int? get diasTrial =>
      _cache == NivelPlan.trial ? _diasRestantes : null;

  /// true si está en trial activo (no vencido)
  static bool get enTrial =>
      _cache == NivelPlan.trial && (_diasRestantes ?? 0) >= 0;

  /// true  → 'pro' | 'activo' | 'trial' vigente (acceso completo)
  /// false → 'basico' vencido | vencido | desconocido
  static bool get esPro {
    final n = _cache ?? NivelPlan.desconocido;
    return n == NivelPlan.pro || n == NivelPlan.trial;
  }

  static NivelPlan get nivel => _cache ?? NivelPlan.desconocido;

  /// Días restantes en el plan actual (cualquier plan con fecha, null si no aplica)
  static int? get diasEnPlan => _diasRestantes;

  /// Carga el plan desde Supabase (si hay internet) y cachea localmente.
  /// Sin internet usa SharedPreferences. Si nunca hubo internet → desconocido.
  static Future<NivelPlan> cargar() async {
    final online = await SupabaseService.isOnlineAsync;

    if (online) {
      try {
        final sus    = await SupabaseService.getSuscripcion();
        final raw    = sus?['plan_activo'] as String? ?? '';
        final venceStr = sus?['suscripcion_vence'] as String?;

        _cache = _parsear(raw);
        _calcularDias(venceStr);

        // Si el plan tiene fecha y ya venció, marcar como desconocido
        if (venceStr != null && (_diasRestantes ?? 0) < 0) {
          _cache = NivelPlan.desconocido;
        }

        // Persistir para uso offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPlanActivo, raw);
        if (venceStr != null) {
          await prefs.setString(_kVence, venceStr);
        } else {
          await prefs.remove(_kVence);
        }
      } catch (_) {
        await _cargarDesdeCache();
      }
    } else {
      await _cargarDesdeCache();
    }

    return _cache!;
  }

  /// Lee plan y fecha desde SharedPreferences y evalúa si venció.
  static Future<void> _cargarDesdeCache() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final raw      = prefs.getString(_kPlanActivo);
      final venceStr = prefs.getString(_kVence);

      if (raw == null) {
        // Primera vez sin internet: no penalizar
        _cache        = NivelPlan.desconocido;
        _diasRestantes = null;
        return;
      }

      _cache = _parsear(raw);
      _calcularDias(venceStr);

      // Si la fecha guardada ya pasó según el reloj local → bloquear
      if (venceStr != null && (_diasRestantes ?? 0) < 0) {
        _cache = NivelPlan.desconocido;
      }
    } catch (_) {
      _cache        = NivelPlan.desconocido;
      _diasRestantes = null;
    }
  }

  static void _calcularDias(String? venceStr) {
    if (venceStr == null) {
      _diasRestantes = null;
      return;
    }
    try {
      final vence    = DateTime.parse(venceStr.replaceAll('+00:00', 'Z'));
      _diasRestantes = vence.difference(DateTime.now()).inDays;
    } catch (_) {
      _diasRestantes = null;
    }
  }

  /// Devuelve días restantes + si está vencida usando solo caché local.
  /// Úsalo en el dashboard cuando no hay internet.
  static Future<({int? dias, bool vencida})> diasRestantesOffline() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final venceStr = prefs.getString(_kVence);
      if (venceStr == null) return (dias: null, vencida: false);
      final vence = DateTime.parse(venceStr.replaceAll('+00:00', 'Z'));
      final dias  = vence.difference(DateTime.now()).inDays;
      return (dias: dias, vencida: dias < 0);
    } catch (_) {
      return (dias: null, vencida: false);
    }
  }

  static void limpiar() {
    _cache        = null;
    _diasRestantes = null;
  }

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
