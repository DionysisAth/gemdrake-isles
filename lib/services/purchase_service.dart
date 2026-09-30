import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/game_config.dart';
import '../logic/game_controller.dart';

/// Real-money purchases through Google Play Billing and the App Store.
abstract class PurchaseService extends ChangeNotifier {
  Future<void> init();

  /// True once the store answered and at least one product is for sale.
  bool get available;

  /// The store's price for [productId] in the player's currency, or null
  /// if the product isn't set up in the store.
  String? price(String productId);

  /// A payment for [productId] is waiting (e.g. "ask to buy", slow card).
  bool pending(String productId);

  /// Starts a purchase. The reward is handed out when the store confirms.
  Future<void> buy(String productId);

  /// Asks the store for earlier purchases (subscriptions). Needed on iOS
  /// for a "Restore purchases" button.
  Future<void> restore();

  /// Messages for the player (errors, "payment pending").
  Stream<String> get messages;
}

/// Used where there's no store (tests, desktop) or when the store is off.
class NoPurchaseService extends PurchaseService {
  final _messages = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  bool get available => false;

  @override
  String? price(String productId) => null;

  @override
  bool pending(String productId) => false;

  @override
  Future<void> buy(String productId) async =>
      _messages.add('The store is not available right now.');

  @override
  Future<void> restore() async {}

  @override
  Stream<String> get messages => _messages.stream;
}

/// Store purchases with the official `in_app_purchase` plugin.
///
/// Consumables are consumed only after the game has saved the reward, and
/// every transaction id is remembered, so a payment is never lost or given
/// twice (e.g. if the app is killed mid-purchase, the store sends it again
/// on the next launch). There's no receipt server: see README.
class StorePurchaseService extends PurchaseService {
  StorePurchaseService(this.game);

  final GameController game;
  final _iap = InAppPurchase.instance;
  final _messages = StreamController<String>.broadcast();
  final Map<String, ProductDetails> _products = {};
  final Set<String> _pending = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  StoreConfig get _config => game.config.store;

  @override
  bool get available => _available && _products.isNotEmpty;

  @override
  String? price(String productId) => _products[productId]?.price;

  @override
  bool pending(String productId) => _pending.contains(productId);

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> init() async {
    if (!_config.enabled) return;
    // Listen first: unfinished purchases are delivered right away.
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Purchase stream: $e'),
    );
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      final ids = {for (final p in _config.products) p.id};
      final res = await _iap.queryProductDetails(ids);
      for (final p in res.productDetails) {
        _products[p.id] = p;
      }
      if (res.notFoundIDs.isNotEmpty) {
        debugPrint('Products not set up in the store: ${res.notFoundIDs}');
      }
      notifyListeners();
      // Google Play: pick up purchases that were paid but not yet handed
      // out, and check the subscription. (On iOS this would ask for the
      // Apple ID password, so it only runs from the Restore button.)
      if (Platform.isAndroid) await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Store init failed: $e');
    }
  }

  @override
  Future<void> buy(String productId) async {
    final details = _products[productId];
    final def = _config.product(productId);
    if (details == null || def == null) {
      _messages.add('This item is not available right now.');
      return;
    }
    final param = PurchaseParam(productDetails: details);
    try {
      if (def.subscription) {
        await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        // Consumed by hand once the reward is saved (see _deliver).
        await _iap.buyConsumable(purchaseParam: param, autoConsume: false);
      }
    } catch (e) {
      debugPrint('Buy failed: $e');
      _messages.add('The purchase could not be started. Please try again.');
    }
  }

  @override
  Future<void> restore() async {
    if (!_available) {
      _messages.add('The store is not available right now.');
      return;
    }
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _pending.add(p.productID);
          _messages.add(
            'Payment pending. Your reward arrives as soon as it goes through.',
          );
        case PurchaseStatus.error:
          _pending.remove(p.productID);
          _messages.add('The purchase did not go through.');
        case PurchaseStatus.canceled:
          _pending.remove(p.productID);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pending.remove(p.productID);
          await _deliver(p);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('Complete purchase failed: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _deliver(PurchaseDetails p) async {
    final def = _config.product(p.productID);
    if (def == null) return;
    final at = _date(p);
    if (def.subscription) {
      if (p.status == PurchaseStatus.restored && Platform.isAndroid) {
        // Google Play only lists subscriptions that are still active.
        game.confirmVip(const Duration(days: 3));
      } else {
        game.grantPurchase(def.id, _txId(p), at: at);
      }
      return;
    }
    game.grantPurchase(def.id, _txId(p), at: at);
    await game.save(immediate: true);
    if (Platform.isAndroid) {
      // Frees the product so it can be bought again.
      try {
        await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(p);
      } catch (e) {
        debugPrint('Consume failed: $e');
      }
    }
  }

  String _txId(PurchaseDetails p) =>
      p.purchaseID ?? '${p.productID}@${p.transactionDate}';

  DateTime? _date(PurchaseDetails p) {
    final ms = int.tryParse(p.transactionDate ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _messages.close();
    super.dispose();
  }
}
