class StockTake {
  String? id;
  String storeId;
  String? conductedBy;
  DateTime stockTakeDate;
  DateTime? startTime;
  DateTime? endTime;
  String status;
  String? notes;
  bool isOffline;
  DateTime? syncedAt;
  DateTime createdAt;
  DateTime updatedAt;

  StockTake({
    this.id,
    required this.storeId,
    this.conductedBy,
    required this.stockTakeDate,
    this.startTime,
    this.endTime,
    this.status = 'draft',
    this.notes,
    this.isOffline = true,
    this.syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'conducted_by': conductedBy,
      'stock_take_date': stockTakeDate.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'notes': notes,
      'is_offline': isOffline ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StockTake.fromMap(Map<String, dynamic> map) {
    return StockTake(
      id: map['id'],
      storeId: map['store_id'] ?? '',
      conductedBy: map['conducted_by'],
      stockTakeDate: DateTime.parse(map['stock_take_date']),
      startTime:
          map['start_time'] != null ? DateTime.parse(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      status: map['status'] ?? 'draft',
      notes: map['notes'],
      isOffline: map['is_offline'] == 1,
      syncedAt:
          map['synced_at'] != null ? DateTime.parse(map['synced_at']) : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }
}
