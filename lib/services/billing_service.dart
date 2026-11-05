import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'plan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IDs de productos en Google Play (deben coincidir EXACTO con Play Console)
// ─────────────────────────────────────────────────────────────────────────────
class BillingProducts {
  // Básico
  static const basicoMensual    = 'negociopro_basico_mensual';
  static const basicoTrimestral = 'negociopro_basico_3meses';
  static const basicoSemestral  = 'negociopro_basico_6meses';
  static const basicoAnual      = 'negociopro_basico_anual';
  // Pro
  static const proMensual       = 'negociopro_pro_mensual';
  static const proTrimestral    = 'negociopro_pro_3meses';
  static const proSemestral     = 'negociopro_pro_6meses';
  static const proAnual         = 'negociopro_pro_anual';

  static const Set<String> todos = {
    basicoMensual, basicoTrimestral, basicoSemestral, basicoAnual,
    proMensual,    proTrimestral,    proSemestral,    proAnual,
  };

  // Metadata de cada producto
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
// BillingService — singleton
// ─────────────────────────────────────────────────────────────────────────────
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];

  // Estado
  bool _disponible = false;
  bool get disponible => _disponible;
  List<ProductDetails> get products => _products;

  // Callbacks para la UI
  void Function(String productId)? onCompraExitosa;
  void Function(String mensaje)? onError;
  void Function()? onCargando;
  void Function()? onCargaCompleta;

  // ── Inicializar ──────────────────────────────────────────────────
  Future<void> init() async {
    _disponible = await InAppPurchase.instance.isAvailable();
    if (!_disponible) return;

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _procesarCompras,
      onError: (e) => onError?.call('Error en la tienda: $e'),
    );

    await cargarProductos();
  }

  Future<void> cargarProductos() async {
    if (!_disponible) return;
    final resp = await InAppPurchase.instance
        .queryProductDetails(BillingProducts.todos);
    _products = resp.productDetails;
    if (kDebugMode && resp.notFoundIDs.isNotEmpty) {
      debugPrint('BillingService — productos no encontrados: ${resp.notFoundIDs}');
    }
  }

  // ── Obtener precio real de Google Play ──────────────────────────
  String? getPrecio(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId).price;
    } catch (_) {
      return null;
    }
  }

  ProductDetails? getProducto(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  // ── Iniciar compra ───────────────────────────────────────────────
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
    final param = PurchaseParam(productDetails: producto);
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      onCargaCompleta?.call();
      onError?.call('No se pudo iniciar la compra: $e');
    }
  }

  // ── Restaurar compras anteriores ─────────────────────────────────
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

  // ── Procesar actualizaciones de compra ───────────────────────────
  Future<void> _procesarCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      switch (compra.status) {
        case PurchaseStatus.pending:
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
          await InAppPurchase.instance.completePurchase(compra);
          break;

        case PurchaseStatus.canceled:
          onCargaCompleta?.call();
          break;
      }
    }
  }

  // ── Activar plan en Supabase ─────────────────────────────────────
  Future<void> _activarPlan(PurchaseDetails compra) async {
    final meta = BillingProducts.info[compra.productID];
    if (meta == null) {
      await InAppPurchase.instance.completePurchase(compra);
      return;
    }

    try {
      final db = Supabase.instance.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) return;

      final meses = meta['meses'] as int;
      final vence = DateTime.now().add(Duration(days: meses * 30));

      final empresa = await db
          .from('empresas')
          .select('id')
          .eq('propietario_id', userId)
          .maybeSingle();

      if (empresa != null) {
        await db.from('empresas').update({
          'plan_activo': meta['plan'],
          'suscripcion_vence': vence.toIso8601String(),
        }).eq('id', empresa['id']);

        // Guardar historial (opcional — tabla compras_play)
        try {
          await db.from('compras_play').insert({
            'empresa_id':  empresa['id'],
            'product_id':  compra.productID,
            'purchase_id': compra.purchaseID,
            'plan':        meta['plan'],
            'periodo':     meta['periodo'],
            'meses':       meses,
            'vence':       vence.toIso8601String(),
            'comprado_en': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          // Tabla puede no existir aún — no bloquear la activación
        }
      }

      await PlanService.cargar();
      onCargaCompleta?.call();
      onCompraExitosa?.call(compra.productID);
    } catch (e) {
      onCargaCompleta?.call();
      onError?.call('Error al activar tu plan: $e');
    } finally {
      await InAppPurchase.instance.completePurchase(compra);
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
