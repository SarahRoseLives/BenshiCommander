// services/donation_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Use clear, descriptive product IDs. You will create these in the Google Play Console.
const String _oneTimeDonationId = 'donation_coffee';
const String _monthlySubscriptionId = 'donation_subscription_monthly';
const String _yearlySubscriptionId = 'donation_subscription_yearly';

class DonationService extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // List of product IDs you want to offer
  final List<String> _productIds = <String>[
    _oneTimeDonationId,
    _monthlySubscriptionId,
    _yearlySubscriptionId,
  ];

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _loading = true;
  bool get loading => _loading;

  // --- Initialization ---
  Future<void> initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (_isAvailable) {
      await _loadProducts();
      _listenToPurchaseUpdates();
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  // --- Load Products from Google Play ---
  Future<void> _loadProducts() async {
    ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds.toSet());
    if (response.error == null) {
      _products = response.productDetails;
    }
    _loading = false;
    notifyListeners();
  }

  // --- Listen to Purchase Stream ---
  void _listenToPurchaseUpdates() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
  }

  // --- Handle Purchase Updates ---
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show a loading indicator
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Grant the user their purchase. For donations, this is usually just a 'thank you'.
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  // --- Make a Purchase ---
  Future<void> makePurchase(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    // For subscriptions, use buyNonConsumable
    // await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}