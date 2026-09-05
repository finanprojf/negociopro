import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Servicio para programar cuadres de caja automáticos con notificación.
class CuadreAutomaticoService {
  static const _notifId = 42;
  static const _channel = AndroidNotificationChannel(
    'cuadre_automatico',
    'Cuadre de Caja',
    description: 'Recordatorio automático para hacer el cuadre de caja',
    importance: Importance.high,
  );

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;

  // ── Keys de SharedPreferences ─────────────────────────────
  static const _kActivo    = 'cuadre_auto_activo';
  static const _kHora      = 'cuadre_auto_hora';    // int: hora del día (0-23)
  static const _kMinuto    = 'cuadre_auto_minuto';  // int
  static const _kIntervalo = 'cuadre_auto_intervalo'; // int: horas (0 = usar hora fija)

  // ── Inicialización (llamar en main.dart) ──────────────────
  static Future<void> init() async {
    if (_iniciado) return;
    tz.initializeTimeZones();

    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (_) {},
    );
    _iniciado = true;
  }

  // ── Getters de preferencias ───────────────────────────────
  static Future<bool>   isActivo()    async => (await SharedPreferences.getInstance()).getBool(_kActivo)    ?? false;
  static Future<int>    getHora()     async => (await SharedPreferences.getInstance()).getInt(_kHora)       ?? 22;
  static Future<int>    getMinuto()   async => (await SharedPreferences.getInstance()).getInt(_kMinuto)     ?? 0;
  static Future<int>    getIntervalo()async => (await SharedPreferences.getInstance()).getInt(_kIntervalo)  ?? 0;

  // ── Guardar y reprogramar ─────────────────────────────────
  static Future<void> guardar({
    required bool activo,
    required int hora,
    required int minuto,
    required int intervaloHoras, // 0 = hora fija, 8/12/24 = cada X horas
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActivo, activo);
    await prefs.setInt(_kHora, hora);
    await prefs.setInt(_kMinuto, minuto);
    await prefs.setInt(_kIntervalo, intervaloHoras);
    await cancelar();
    if (activo) await _programar(hora, minuto, intervaloHoras);
  }

  static Future<void> cancelar() async {
    await _plugin.cancel(_notifId);
  }

  static Future<void> _programar(int hora, int minuto, int intervalo) async {
    final ahora = tz.TZDateTime.now(tz.local);
    tz.TZDateTime proxima;

    if (intervalo > 0) {
      // Cada X horas desde ahora
      proxima = ahora.add(Duration(hours: intervalo));
    } else {
      // Hora fija diaria
      proxima = tz.TZDateTime(tz.local,
          ahora.year, ahora.month, ahora.day, hora, minuto);
      if (proxima.isBefore(ahora)) {
        proxima = proxima.add(const Duration(days: 1));
      }
    }

    await _plugin.zonedSchedule(
      _notifId,
      '💰 Hora del Cuadre de Caja',
      'Abre NegocioPro para revisar cuánto debe haber en caja',
      proxima,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: intervalo == 0
          ? DateTimeComponents.time   // repetir cada día a la misma hora
          : null,                     // una sola vez (se reprograma al abrir app)
    );
  }

  /// Llamar al abrir la app si hay intervalo activo (re-programa la siguiente)
  static Future<void> reprogramarSiIntervalo() async {
    if (!await isActivo()) return;
    final intervalo = await getIntervalo();
    if (intervalo == 0) return; // hora fija — ya es periódica, no hace falta
    final hora    = await getHora();
    final minuto  = await getMinuto();
    await cancelar();
    await _programar(hora, minuto, intervalo);
  }
}
