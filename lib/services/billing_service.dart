import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'plan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IDs de productos en Google Play
// ─────────────────────────────────────────────────────────────────────────────
class BillingProducts {
  static const basicoMensual    = 'negociopro_basico_mensual';
  static const basicoTrimestral = 'negociopro_basico_3meses';
  static const basicoSemestral  = 'negociopro_basico_6meses';
  static const basicoAnual      = 'negociopro_basico_anual';
  static const proMensual       = 'negociopro_pro_mensual';
  static const proTrimestral    = 'negociopro_pro_3meses';
  static const proSemestral     = 'negociopro_pro_6meses';
  static const proAnual         = 'negociopro_pro_anual';

  static const Set<String> todos = {
    basicoMensual, basicoTrimestral, basicoSemestral, basicoAnual,
    proMensual,    proTrimestral,    proSemestral,    proAnual,
  };

  static const Map<String, Map<String, dynamic>> info = {
    basicoMensual:    {'plan': 'basico', 'meses': 1,  'periodo': 'Mensual'},
    basicoTrimestral: {'plan': 'basico', 'meses': 3,  'periodo': '3 meses'},
    basicoSemestral:  {'plan': 'basico', 'meses': 6,  'periodo': '6 meses'},
    basicoAnual:      {'plan': 'basico', 'meses': 12, 'periodo': 'Anual'},
    proMensual:       {'plan': 'pro',    'meses': 1,  'periodo': 'Mensual'},
    proTrimestral:    {'plan': 'pro',    'meses': 3,  'periodo': '3 meses'},
    proSemestral:     {'plan': 'pro',    'meses': 6,  'periodo': '6 meses'},
    proAnual:         {'plan': 'pro',    'meses': 12, 'periodo': 'Anual'},
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Clave para compras pendientes guardadas localmente
// ─────────────────────────────────────────────────────────────────────────────
const _kPendingKey = 'billing_pending_activations';

// ─────────────────────────────────────────────────────────────────────────────
// BillingService — singleton blindado
// ─────────────────────────────────────────────────────────────────────────────
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];

  bool _disponible = false;
  bool get disponible => _disponible;
  List<ProductDetails> get products => _products;

  // Callbacks para la UI
  void Function(String productId)? onCompraExitosa;
  void Function(String mensaje)?   onError;
  void Function()?                 onCargando;
  void Function()?                 onCargaCompleta;

  // ── Inicializar ──────────────────────────────────────────────────────────
  Future<void> init() async {
    _disponible = await InAppPurchase.instance.isAvailable();
    if (!_disponible) return;

    // Escuchar el stream ANTES de restaurar — para no perder eventos
    _sub?.cancel();
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _procesarCompras,
      onError: (e) => onError?.call('Error en la tienda: $e'),
    );

    await cargarProductos();

    // ── BLINDAJE 1: Procesar compras pendientes guardadas localmente
    await _procesarPendientesLocales();

    // ── BLINDAJE 2: Restaurar compras de Google Play al iniciar
    //   Esto captura compras que ocurrieron con el app cerrado
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      // Silencioso — no es crítico en el inicio
    }
  }

  Future<void> cargarProductos() async {
    if (!_disponible) return;
    final resp = await InAppPurchase.instance
        .queryProductDetails(BillingProducts.todos);
    _products = resp.productDetails;
    if (kDebugMode && resp.notFoundIDs.isNotEmpty) {
      debugPrint('BillingService — no encontrados: ${resp.notFoundIDs}');
    }
  }

  String? getPrecio(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId).price;
    } catch (_) { return null; }
  }

  ProductDetails? getProducto(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) { return null; }
  }

  // ── Iniciar compra ───────────────────────────────────────────────────────
  Future<void> comprar(String productId) async {
    if (!_disponible) {
      onError?.call('Google Play no está disponible en este dispositivo.');
      return;
    }
    final producto = getProducto(productId);
    if (producto == null) {
      onError?.call('Producto no disponible. Intenta más tarde.');
      return;
    }
    onCargando?.call();
    try {
      final param = PurchaseParam(productDetails: producto);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      onCargaCompleta?.call();
      onError?.call('No se pudo iniciar la compra: $e');
    }
  }

  // ── Restaurar compras anteriores (botón manual) ──────────────────────────
  Future<void> restaurar() async {
    if (!_disponible) return;
    onCargando?.call();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      onCargaCompleta?.call();
      onError?.call('Error al restaurar: $e');
    }
  }

  // ── Procesar actualizaciones del stream ──────────────────────────────────
  Future<void> _procesarCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      switch (compra.status) {
        case PurchaseStatus.pending:
          // Compra pendiente (ej. aprobación familiar) — guardar localmente
          await _guardarPendienteLocal(compra.productID, compra.purchaseID ?? '');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _activarPlan(compra);
          break;

        case PurchaseStatus.error:
          onCargaCompleta?.call();
          final msg = compra.error?.message ?? 'Error desconocido';
          if (!msg.toLowerCase().contains('cancel') &&
              !msg.toLowerCase().contains('user_canceled')) {
            onError?.call('Error en la compra: $msg');
          }
          if (compra.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(compra);
          }
          break;

        case PurchaseStatus.canceled:
          onCargaCompleta?.call();
          if (compra.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(compra);
          }
          break;
      }
    }
  }

  // ── Activar plan con reintentos ──────────────────────────────────────────
  Future<void> _activarPlan(PurchaseDetails compra) async {
    final meta = BillingProducts.info[compra.productID];
    if (meta == null) {
      if (compra.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(compra);
      }
      return;
    }

    // ── BLINDAJE 3: 3 reintentos con espera entre cada uno
    bool activado = false;
    String? ultimoError;

    for (int intento = 1; intento <= 3; intento++) {
      try {
        final db = Supabase.instance.client;
        final userId = db.auth.currentUser?.id;
        if (userId == null) break;

        final meses = meta['meses'] as int;
        // Calcular vencimiento desde HOY
        final ahora = DateTime.now();
        final vence = DateTime(
          ahora.year, ahora.month + meses, ahora.day,
          ahora.hour, ahora.minute,
        );

        final empresa = await db
            .from('empresas')
            .select('id')
            .eq('propietario_id', userId)
            .maybeSingle();

        if (empresa == null) break;

        final empresaId = empresa['id'] as String;

        await db.from('empresas').update({
          'plan_activo':        meta['plan'],
          'suscripcion_vence':  vence.toIso8601String(),
        }).eq('id', empresaId);

        // Historial de compra (no bloquea si falla)
        try {
          await db.from('compras_play').insert({
            'empresa_id':  empresaId,
            'product_id':  compra.productID,
            'purchase_id': compra.purchaseID ?? '',
            'plan':        meta['plan'],
            'periodo':     meta['periodo'],
            'meses':       meses,
            'vence':       vence.toIso8601String(),
            'comprado_en': ahora.toIso8601String(),
          });
        } catch (_) {}

        activado = true;
        break; // Éxito — salir del loop

      } catch (e) {
        ultimoError = e.toString();
        if (intento < 3) {
          // Esperar antes del siguiente intento (1s, 2s)
          await Future.delayed(Duration(seconds: intento));
        }
      }
    }

    if (activado) {
      // ── Éxito total: limpiar pendiente local si existía
      await _eliminarPendienteLocal(compra.productID);
      await PlanService.cargar();
      onCargaCompleta?.call();
      onCompraExitosa?.call(compra.productID);
    } else {
      // ── BLINDAJE 4: Guardar localmente para reintentar al próximo inicio
      await _guardarPendienteLocal(compra.productID, compra.purchaseID ?? '');
      onCargaCompleta?.call();
      onError?.call(
        'Tu pago fue procesado por Google.\n'
        'El plan se activará automáticamente cuando tengas conexión.\n'
        '(Error: $ultimoError)',
      );
    }

    // Siempre completar la compra ante Google para que no se repita
    if (compra.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(compra);
      } catch (_) {}
    }
  }

  // ── Guardar compra pendiente localmente ──────────────────────────────────
  Future<void> _guardarPendienteLocal(String productId, String purchaseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingKey);
      final List<dynamic> lista = raw != null ? jsonDecode(raw) : [];
      // Evitar duplicados
      lista.removeWhere((e) => e['productId'] == productId);
      lista.add({
        'productId':  productId,
        'purchaseId': purchaseId,
        'guardadoEn': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_kPendingKey, jsonEncode(lista));
    } catch (_) {}
  }

  Future<void> _eliminarPendienteLocal(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingKey);
      if (raw == null) return;
      final List<dynamic> lista = jsonDecode(raw);
      lista.removeWhere((e) => e['productId'] == productId);
      await prefs.setString(_kPendingKey, jsonEncode(lista));
    } catch (_) {}
  }

  // ── Procesar pendientes guardados localmente al iniciar ──────────────────
  Future<void> _procesarPendientesLocales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingKey);
      if (raw == null || raw == '[]') return;

      final List<dynamic> lista = jsonDecode(raw);
      if (lista.isEmpty) return;

      final db = Supabase.instance.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) return;

      final empresa = await db
          .from('empresas')
          .select('id')
          .eq('propietario_id', userId)
          .maybeSingle();
      if (empresa == null) return;

      final empresaId = empresa['id'] as String;
      final List<dynamic> fallidos = [];

      for (final item in lista) {
        final productId = item['productId'] as String;
        final meta = BillingProducts.info[productId];
        if (meta == null) continue;

        try {
          final meses = meta['meses'] as int;
          final ahora = DateTime.now();
          final vence = DateTime(ahora.year, ahora.month + meses, ahora.day);

          await db.from('empresas').update({
            'plan_activo':       meta['plan'],
            'suscripcion_vence': vence.toIso8601String(),
          }).eq('id', empresaId);

          // Éxito — no agregar a fallidos
          if (kDebugMode) debugPrint('BillingService — pendiente activado: $productId');
        } catch (e) {
          fallidos.add(item); // Volver a guardar para el próximo intento
        }
      }

      await prefs.setString(_kPendingKey, jsonEncode(fallidos));
      if (fallidos.length < lista.length) {
        await PlanService.cargar(); // Refrescar plan si activamos algo
      }
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
  }
}
