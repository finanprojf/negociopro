import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/cuadre_automatico_service.dart';
import 'services/pin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/seguridad/pin_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar locale para fechas en español
  await initializeDateFormatting('es_DO', null);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await CuadreAutomaticoService.init();
  await CuadreAutomaticoService.reprogramarSiIntervalo();

  runApp(const NegocioProApp());
}

class NegocioProApp extends StatefulWidget {
  const NegocioProApp({super.key});
  @override State<NegocioProApp> createState() => _NegocioProAppState();
}

class _NegocioProAppState extends State<NegocioProApp>
    with WidgetsBindingObserver {
  bool _bloqueado = false;
  bool _pinActivo = false;

  static const _keyPendingLock = 'pin_pending_lock';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarPin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al iniciar la app: si el PIN está activo y quedó una marca de bloqueo
  /// pendiente (la app fue cerrada/matada), mostramos la pantalla de PIN.
  Future<void> _iniciarPin() async {
    final activo = await PinService.habilitado;
    if (!activo) { if (mounted) setState(() => _pinActivo = false); return; }

    final prefs = await SharedPreferences.getInstance();
    final pendiente = prefs.getBool(_keyPendingLock) ?? false;
    final modo = await PinService.modo;

    // modoBloqueado: siempre bloquea al iniciar
    // modoCerrar: solo bloquea si la app fue matada (flag pendiente)
    final bloqueado = (modo == PinService.modoBloqueado) || pendiente;

    if (mounted) setState(() {
      _pinActivo = true;
      _bloqueado = bloqueado;
    });
  }

  /// Marca que la app está en background/cerrada para que al volver se bloquee.
  Future<void> _marcarPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingLock, true);
  }

  /// Limpia la marca (app volvió al frente normalmente).
  Future<void> _limpiarPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingLock, false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!_pinActivo) return;
    final modo = await PinService.modo;

    if (state == AppLifecycleState.paused) {
      // Siempre marcamos pendiente al ir al fondo (persiste si la app muere)
      await _marcarPendiente();
      // Modo "suspender": bloquea de inmediato también
      if (modo == PinService.modoBloqueado) {
        if (mounted) setState(() => _bloqueado = true);
      }
    }

    if (state == AppLifecycleState.resumed) {
      // NO limpiamos el flag aquí — solo se limpia al desbloquear exitosamente
      // Así si la app fue matada y relanzada, el flag persiste hasta el unlock
      final activo = await PinService.habilitado;
      if (mounted) setState(() => _pinActivo = activo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'DO'),
        Locale('en'),
      ],
      theme: AppTheme.light,
      home: _bloqueado
          ? PinLockScreen(onUnlocked: () async {
            await _limpiarPendiente(); // limpiamos aquí, no en resumed
            if (mounted) setState(() => _bloqueado = false);
          })
          : const AuthWrapper(),
    );
    return app;
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

   return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final event = snapshot.data?.event;

       if (event == AuthChangeEvent.signedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          });
          return const _SplashScreen();
        }

        if (event == AuthChangeEvent.signedOut) {
          return const LoginScreen();
        }

        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F7B5B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.store_rounded,
                  size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('NegocioPro',
                style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.5,
                )),
            const SizedBox(height: 6),
            Text('por FinanPro Solutions',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                )),
            const SizedBox(height: 60),
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}