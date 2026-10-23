import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Niveles de plan de NegocioPro
enum NivelPlan { trial, basico, pro, desconocido }

class PlanService {
  static NivelPlan? _cache;
  static int? _diasTrial; // null = no es trial activo

  static const _kPlanActivo    = 'cached_plan_activo';
  static const _kVence         = 'cached_suscripcion_vence';

  /// Días restantes del trial (null si no aplica)
  static int? get diasTrial => _diasTrial;

  /// true si está en trial activo (no vencido)
  static bool get enTrial => _cache == NivelPlan.trial && (_diasTrial ?? 0) >= 0;

  /// true  → 'pro' | 'activo' | 'trial'  (acceso completo)
  /// false → 'basico' | sin datos (desconocido = denegar para evitar bypass)
  static bool get esPro {
    final n = _cache ?? NivelPlan.desconocido;
    return n == NivelPlan.pro || n == NivelPlan.trial;
  }

  static NivelPlan get nivel => _cache ?? NivelPlan.desconocido;

  /// Carga el plan desde Supabase (si hay internet) y cachea en memoria
  /// y en SharedPreferences. Sin internet usa el caché guardado.
  /// Si nunca se guardó nada → da acceso (instalación nueva sin internet).
  static Future<NivelPlan> cargar() async {
    final online = await SupabaseService.isOnlineAsync;

    if (online) {
      // ── Con internet: leer de Supabase y guardar localmente ──────────
      try {
        final sus = await SupabaseService.getSuscripcion();
        final raw = sus?['plan_activo'] as String? ?? '';
        _cache = _parsear(raw);

        final venceStr = sus?['suscripcion_vence'] as String?;
        if (_cache == NivelPlan.trial && venceStr != null) {
          final vence = DateTime.parse(venceStr);
          _diasTrial = vence.difference(DateTime.now()).inDays;
        } else {
          _diasTrial = null;
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
        // Si falla la red igualmente, caer al caché local
        await _cargarDesdeCache();
      }
    } else {
      // ── Sin internet: usar caché guardado ────────────────────────────
      await _cargarDesdeCache();
    }

    return _cache!;
  }

  /// Lee plan desde SharedPreferences.
  /// Si no hay nada guardado → desconocido (no bloquea: ver [esPro]).
  /// NOTA: desconocido bloquea funciones Pro pero no la app completa;
  ///       si nunca hubo internet el usuario puede seguir en modo básico.
  static Future<void> _cargarDesdeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw      = prefs.getString(_kPlanActivo);
      final venceStr = prefs.getString(_kVence);

      if (raw == null) {
        // Primera vez sin internet: no penalizar, dar desconocido
        _cache    = NivelPlan.desconocido;
        _diasTrial = null;
        return;
      }

      _cache = _parsear(raw);

      if (_cache == NivelPlan.trial && venceStr != null) {
        final vence = DateTime.parse(venceStr);
        _diasTrial  = vence.difference(DateTime.now()).inDays;
        // Si el trial venció según el reloj local, tratar como desconocido
        if (_diasTrial! < 0) _cache = NivelPlan.desconocido;
      } else {
        _diasTrial = null;
      }
    } catch (_) {
      _cache    = NivelPlan.desconocido;
      _diasTrial = null;
    }
  }

  /// Devuelve los días restantes de suscripción usando caché local.
  /// Retorna null si no hay fecha guardada (plan activo sin vencimiento fijo).
  /// Retorna valor negativo si venció según reloj local.
  static Future<({int? dias, bool vencida})> diasRestantesOffline() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final venceStr = prefs.getString(_kVence);
      if (venceStr == null) return (dias: null, vencida: false);
      final vence = DateTime.parse(venceStr);
      final dias  = vence.difference(DateTime.now()).inDays;
      return (dias: dias, vencida: dias < 0);
    } catch (_) {
      return (dias: null, vencida: false);
    }
  }

  static void limpiar() {
    _cache    = null;
    _diasTrial = null;
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
