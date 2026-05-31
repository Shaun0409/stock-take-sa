import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store.dart';
import '../models/product.dart';
import '../models/stock_take.dart';
import '../models/stock_take_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static SharedPreferences? _prefs;

  DatabaseService._internal();

  factory DatabaseService() => _instance;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Initialize database (NO SAMPLE DATA - COMPLETELY EMPTY)
  Future<void> initializeDatabase() async {
    await _initPrefs();
    
    // Only initialize if not already done
    if (_prefs!.containsKey('initialized')) return;
    
    // Mark as initialized without creating any sample data
    _prefs!.setBool('initialized', true);
    
    print('✅ Database initialized (completely empty)');
  }

  // =====================================================
  // STORE OPERATIONS
  // =====================================================

  Future<List<Store>> getStores() async {
    await _initPrefs();
    final storesJson = _prefs!.getStringList('stores') ?? [];
    return storesJson.map((json) => Store.fromMap(jsonDecode(json))).toList();
  }

  Future<Store?> getStore(String id) async {
    final stores = await getStores();
    try {
      return stores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> insertStore(Store store) async {
    await _initPrefs();
    final stores = await getStores();
    final newStore = Store(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      companyId: store.companyId,
      storeName: store.storeName,
      ownerName: store.ownerName,
      ownerPhone: store.ownerPhone,
      address: store.address,
      suburb: store.suburb,
      city: store.city,
      province: store.province,
      storeType: store.storeType,
      isActive: true,
    );
    stores.add(newStore);
    _prefs!.setStringList('stores', stores.map((s) => jsonEncode(s.toMap())).toList());
  }

  Future<void> updateStore(Store store) async {
    await _initPrefs();
    final stores = await getStores();
    final index = stores.indexWhere((s) => s.id == store.id);
    if (index != -1) {
      stores[index] = store;
      _prefs!.setStringList('stores', stores.map((s) => jsonEncode(s.toMap())).toList());
    }
  }

  Future<void> deleteStore(String id) async {
    await _initPrefs();
    final stores = await getStores();
    stores.removeWhere((s) => s.id == id);
    _prefs!.setStringList('stores', stores.map((s) => jsonEncode(s.toMap())).toList());
  }

  // =====================================================
  // PRODUCT OPERATIONS
  // =====================================================

  Future<List<Product>> getProducts({String? category, String? searchQuery}) async {
    await _initPrefs();
    final productsJson = _prefs!.getStringList('products') ?? [];
    var products = productsJson.map((json) => Product.fromMap(jsonDecode(json))).toList();
    
    if (category != null && category != 'All') {
      products = products.where((p) => p.category == category).toList();
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      products = products.where((p) => 
        p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        (p.barcode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    products.sort((a, b) => a.name.compareTo(b.name));
    
    return products;
  }

  Future<List<String>> getCategories() async {
    final products = await getProducts();
    final categories = products.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  Future<Product?> getProduct(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> insertProduct(Product product) async {
    await _initPrefs();
    final products = await getProducts();
    final newProduct = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      companyId: product.companyId,
      barcode: product.barcode,
      name: product.name,
      category: product.category,
      subcategory: product.subcategory,
      unit: product.unit,
      defaultCostPrice: product.defaultCostPrice,
      defaultSellingPrice: product.defaultSellingPrice,
      vatRate: product.vatRate,
      isZeroRated: product.isZeroRated,
      isActive: true,
    );
    products.add(newProduct);
    _prefs!.setStringList('products', products.map((p) => jsonEncode(p.toMap())).toList());
  }

  Future<void> updateProduct(Product product) async {
    await _initPrefs();
    final products = await getProducts();
    final index = products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      products[index] = product;
      _prefs!.setStringList('products', products.map((p) => jsonEncode(p.toMap())).toList());
    }
  }

  Future<void> deleteProduct(String id) async {
    await _initPrefs();
    final products = await getProducts();
    products.removeWhere((p) => p.id == id);
    _prefs!.setStringList('products', products.map((p) => jsonEncode(p.toMap())).toList());
  }

  // =====================================================
  // STOCK TAKE OPERATIONS
  // =====================================================

  Future<String> createStockTake(StockTake stockTake) async {
    await _initPrefs();
    final stockTakes = await getStockTakes();
    final id = stockTake.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final newStockTake = StockTake(
      id: id,
      storeId: stockTake.storeId,
      conductedBy: stockTake.conductedBy,
      stockTakeDate: stockTake.stockTakeDate,
      startTime: stockTake.startTime,
      endTime: stockTake.endTime,
      status: stockTake.status,
      notes: stockTake.notes,
      isOffline: stockTake.isOffline,
      syncedAt: stockTake.syncedAt,
      createdAt: stockTake.createdAt,
      updatedAt: stockTake.updatedAt,
    );
    stockTakes.add(newStockTake);
    _prefs!.setStringList('stock_takes', stockTakes.map((s) => jsonEncode(s.toMap())).toList());
    return id;
  }

  Future<List<StockTake>> getStockTakes({String? storeId, String? status}) async {
    await _initPrefs();
    final stockTakesJson = _prefs!.getStringList('stock_takes') ?? [];
    List<StockTake> stockTakes = [];
    
    for (var json in stockTakesJson) {
      try {
        stockTakes.add(StockTake.fromMap(jsonDecode(json)));
      } catch (e) {
        print('Error parsing stock take: $e');
      }
    }
    
    if (storeId != null) {
      stockTakes = stockTakes.where((s) => s.storeId == storeId).toList();
    }
    
    if (status != null) {
      stockTakes = stockTakes.where((s) => s.status == status).toList();
    }
    
    stockTakes.sort((a, b) => b.stockTakeDate.compareTo(a.stockTakeDate));
    
    return stockTakes;
  }

  Future<StockTake?> getStockTake(String id) async {
    final stockTakes = await getStockTakes();
    try {
      return stockTakes.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<StockTake>> getUnsyncedStockTakes() async {
    final allStockTakes = await getStockTakes();
    return allStockTakes.where((st) => 
      st.status == 'completed' && st.syncedAt == null
    ).toList();
  }

  Future<void> markAsSynced(String stockTakeId) async {
    await _initPrefs();
    final stockTakes = await getStockTakes();
    final index = stockTakes.indexWhere((s) => s.id == stockTakeId);
    if (index != -1) {
      final updated = StockTake(
        id: stockTakes[index].id,
        storeId: stockTakes[index].storeId,
        conductedBy: stockTakes[index].conductedBy,
        stockTakeDate: stockTakes[index].stockTakeDate,
        startTime: stockTakes[index].startTime,
        endTime: stockTakes[index].endTime,
        status: stockTakes[index].status,
        notes: stockTakes[index].notes,
        isOffline: stockTakes[index].isOffline,
        syncedAt: DateTime.now(),
        createdAt: stockTakes[index].createdAt,
        updatedAt: DateTime.now(),
      );
      stockTakes[index] = updated;
      _prefs!.setStringList('stock_takes', stockTakes.map((s) => jsonEncode(s.toMap())).toList());
    }
  }

  Future<void> updateStockTakeStatus(String id, String status, {DateTime? endTime}) async {
    await _initPrefs();
    final stockTakes = await getStockTakes();
    final index = stockTakes.indexWhere((s) => s.id == id);
    if (index != -1) {
      final updated = StockTake(
        id: stockTakes[index].id,
        storeId: stockTakes[index].storeId,
        conductedBy: stockTakes[index].conductedBy,
        stockTakeDate: stockTakes[index].stockTakeDate,
        startTime: stockTakes[index].startTime,
        endTime: endTime ?? stockTakes[index].endTime,
        status: status,
        notes: stockTakes[index].notes,
        isOffline: stockTakes[index].isOffline,
        syncedAt: stockTakes[index].syncedAt,
        createdAt: stockTakes[index].createdAt,
        updatedAt: DateTime.now(),
      );
      stockTakes[index] = updated;
      _prefs!.setStringList('stock_takes', stockTakes.map((s) => jsonEncode(s.toMap())).toList());
    }
  }

  // =====================================================
  // STOCK TAKE ITEMS OPERATIONS
  // =====================================================

  Future<void> saveStockTakeItem(StockTakeItem item) async {
    await _initPrefs();
    final itemsKey = 'stock_take_items_${item.stockTakeId}';
    final itemsJson = _prefs!.getStringList(itemsKey) ?? [];
    var items = itemsJson.map((json) => StockTakeItem.fromMap(jsonDecode(json))).toList();
    
    final index = items.indexWhere((i) => i.productId == item.productId);
    if (index != -1) {
      items[index] = item;
    } else {
      items.add(item);
    }
    
    _prefs!.setStringList(itemsKey, items.map((i) => jsonEncode(i.toMap())).toList());
  }

  Future<List<StockTakeItem>> getStockTakeItems(String stockTakeId) async {
    await _initPrefs();
    final itemsKey = 'stock_take_items_$stockTakeId';
    final itemsJson = _prefs!.getStringList(itemsKey) ?? [];
    return itemsJson.map((json) => StockTakeItem.fromMap(jsonDecode(json))).toList();
  }

  Future<void> deleteStockTakeItems(String stockTakeId) async {
    await _initPrefs();
    final itemsKey = 'stock_take_items_$stockTakeId';
    await _prefs!.remove(itemsKey);
  }

  // =====================================================
  // STOCK TAKE SUMMARY
  // =====================================================

  Future<Map<String, dynamic>> getStockTakeSummary(String stockTakeId) async {
    final items = await getStockTakeItems(stockTakeId);
    
    double totalCost = 0;
    double totalSelling = 0;
    int totalItems = 0;
    
    for (var item in items) {
      totalCost += item.countedQuantity * item.costPriceAtTime;
      totalSelling += item.countedQuantity * item.sellingPriceAtTime;
      totalItems += item.countedQuantity.toInt();
    }
    
    return {
      'total_items': totalItems,
      'total_cost_value': totalCost,
      'total_selling_value': totalSelling,
      'potential_profit': totalSelling - totalCost,
      'unique_products': items.length,
    };
  }

  // =====================================================
  // SALES AND PURCHASES (For Shrinkage Calculation)
  // =====================================================

  Future<void> saveSalesData(String storeId, double amount, DateTime date) async {
    await _initPrefs();
    final salesKey = 'sales_$storeId';
    final salesJson = _prefs!.getStringList(salesKey) ?? [];
    final sales = salesJson.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
    
    sales.add({
      'amount': amount,
      'date': date.toIso8601String(),
    });
    
    _prefs!.setStringList(salesKey, sales.map((s) => jsonEncode(s)).toList());
  }

  Future<double> getTotalSales(String storeId, DateTime startDate, DateTime endDate) async {
    await _initPrefs();
    final salesKey = 'sales_$storeId';
    final salesJson = _prefs!.getStringList(salesKey) ?? [];
    final sales = salesJson.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
    
    double total = 0;
    for (var sale in sales) {
      final saleDate = DateTime.parse(sale['date']);
      if (saleDate.isAfter(startDate) && saleDate.isBefore(endDate)) {
        total += sale['amount'];
      }
    }
    return total;
  }

  Future<void> savePurchaseData(String storeId, double amount, DateTime date) async {
    await _initPrefs();
    final purchasesKey = 'purchases_$storeId';
    final purchasesJson = _prefs!.getStringList(purchasesKey) ?? [];
    final purchases = purchasesJson.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
    
    purchases.add({
      'amount': amount,
      'date': date.toIso8601String(),
    });
    
    _prefs!.setStringList(purchasesKey, purchases.map((p) => jsonEncode(p)).toList());
  }

  Future<double> getTotalPurchases(String storeId, DateTime startDate, DateTime endDate) async {
    await _initPrefs();
    final purchasesKey = 'purchases_$storeId';
    final purchasesJson = _prefs!.getStringList(purchasesKey) ?? [];
    final purchases = purchasesJson.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
    
    double total = 0;
    for (var purchase in purchases) {
      final purchaseDate = DateTime.parse(purchase['date']);
      if (purchaseDate.isAfter(startDate) && purchaseDate.isBefore(endDate)) {
        total += purchase['amount'];
      }
    }
    return total;
  }

  // =====================================================
  // SHRINKAGE CALCULATION
  // =====================================================

  Future<Map<String, dynamic>> calculateShrinkage(String storeId, DateTime startDate, DateTime endDate) async {
    final allStockTakes = await getStockTakes(storeId: storeId);
    
    if (allStockTakes.isEmpty) {
      return {
        'error': 'No stock take found for this period. Please complete a stock take first.',
        'shrinkage_percentage': 0,
        'shrinkage_value': 0,
        'opening_stock_value': 0,
        'purchases_value': 0,
        'sales_value': 0,
        'expected_closing_value': 0,
        'actual_closing_value': 0,
        'meets_target': true,
        'stock_take_date': null,
      };
    }
    
    final stockTake = allStockTakes.first;
    
    final items = await getStockTakeItems(stockTake.id!);
    double countedValue = 0;
    for (var item in items) {
      countedValue += item.countedQuantity * item.costPriceAtTime;
    }
    
    final sales = await getTotalSales(storeId, startDate, endDate);
    final purchases = await getTotalPurchases(storeId, startDate, endDate);
    
    double openingValue = 0;
    if (allStockTakes.length > 1) {
      final previousStockTake = allStockTakes[1];
      final previousItems = await getStockTakeItems(previousStockTake.id!);
      for (var item in previousItems) {
        openingValue += item.countedQuantity * item.costPriceAtTime;
      }
    }
    
    final expectedClosing = openingValue + purchases - sales;
    final shrinkageValue = expectedClosing - countedValue;
    final shrinkagePercentage = expectedClosing > 0 ? (shrinkageValue / expectedClosing) * 100 : 0;
    
    return {
      'opening_stock_value': openingValue,
      'purchases_value': purchases,
      'sales_value': sales,
      'expected_closing_value': expectedClosing,
      'actual_closing_value': countedValue,
      'shrinkage_value': shrinkageValue,
      'shrinkage_percentage': shrinkagePercentage.abs(),
      'meets_target': shrinkagePercentage.abs() <= 2.0,
      'stock_take_date': stockTake.stockTakeDate.toIso8601String(),
      'is_profit': shrinkageValue < 0,
    };
  }
}