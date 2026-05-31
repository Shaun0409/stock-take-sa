class StockTakeItem {
  String? id;
  String stockTakeId;
  String productId;
  double countedQuantity;
  double costPriceAtTime;
  double sellingPriceAtTime;
  DateTime? expiryDate;
  String? batchNumber;
  bool isSpoiled;
  String? notes;

  StockTakeItem({
    this.id,
    required this.stockTakeId,
    required this.productId,
    required this.countedQuantity,
    required this.costPriceAtTime,
    required this.sellingPriceAtTime,
    this.expiryDate,
    this.batchNumber,
    this.isSpoiled = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_take_id': stockTakeId,
      'product_id': productId,
      'counted_quantity': countedQuantity,
      'cost_price_at_time': costPriceAtTime,
      'selling_price_at_time': sellingPriceAtTime,
      'expiry_date': expiryDate?.toIso8601String(),
      'batch_number': batchNumber,
      'is_spoiled': isSpoiled ? 1 : 0,
      'notes': notes,
    };
  }

  factory StockTakeItem.fromMap(Map<String, dynamic> map) {
    return StockTakeItem(
      id: map['id'],
      stockTakeId: map['stock_take_id'] ?? '',
      productId: map['product_id'] ?? '',
      countedQuantity: (map['counted_quantity'] ?? 0).toDouble(),
      costPriceAtTime: (map['cost_price_at_time'] ?? 0).toDouble(),
      sellingPriceAtTime: (map['selling_price_at_time'] ?? 0).toDouble(),
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'])
          : null,
      batchNumber: map['batch_number'],
      isSpoiled: map['is_spoiled'] == 1,
      notes: map['notes'],
    );
  }
}
