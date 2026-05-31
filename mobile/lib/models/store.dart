class Store {
  String? id;
  String companyId;
  String storeName;
  String? ownerName;
  String? ownerPhone;
  String? address;
  String? suburb;
  String? city;
  String? province;
  String? storeType;
  bool isActive;
  DateTime? lastStockTakeDate;

  Store({
    this.id,
    required this.companyId,
    required this.storeName,
    this.ownerName,
    this.ownerPhone,
    this.address,
    this.suburb,
    this.city,
    this.province,
    this.storeType,
    this.isActive = true,
    this.lastStockTakeDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'store_name': storeName,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'address': address,
      'suburb': suburb,
      'city': city,
      'province': province,
      'store_type': storeType,
      'is_active': isActive ? 1 : 0,
      'last_stock_take_date': lastStockTakeDate?.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'],
      companyId: map['company_id'] ?? '',
      storeName: map['store_name'] ?? '',
      ownerName: map['owner_name'],
      ownerPhone: map['owner_phone'],
      address: map['address'],
      suburb: map['suburb'],
      city: map['city'],
      province: map['province'],
      storeType: map['store_type'],
      isActive: map['is_active'] == 1,
      lastStockTakeDate: map['last_stock_take_date'] != null 
          ? DateTime.tryParse(map['last_stock_take_date']) 
          : null,
    );
  }
}
