class Product {
  String? id;
  String companyId;
  String? barcode;
  String name;
  String category;
  String? subcategory;
  String unit;
  double defaultCostPrice;
  double defaultSellingPrice;
  double vatRate;
  bool isZeroRated;
  bool isActive;

  Product({
    this.id,
    required this.companyId,
    this.barcode,
    required this.name,
    required this.category,
    this.subcategory,
    this.unit = 'each',
    required this.defaultCostPrice,
    required this.defaultSellingPrice,
    this.vatRate = 15.0,
    this.isZeroRated = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'barcode': barcode,
      'name': name,
      'category': category,
      'subcategory': subcategory,
      'unit': unit,
      'default_cost_price': defaultCostPrice,
      'default_selling_price': defaultSellingPrice,
      'vat_rate': vatRate,
      'is_zero_rated': isZeroRated ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      companyId: map['company_id'] ?? '',
      barcode: map['barcode'],
      name: map['name'] ?? '',
      category: map['category'] ?? 'Uncategorized',
      subcategory: map['subcategory'],
      unit: map['unit'] ?? 'each',
      defaultCostPrice: (map['default_cost_price'] ?? 0).toDouble(),
      defaultSellingPrice: (map['default_selling_price'] ?? 0).toDouble(),
      vatRate: (map['vat_rate'] ?? 15).toDouble(),
      isZeroRated: map['is_zero_rated'] == 1,
      isActive: map['is_active'] == 1,
    );
  }
}
