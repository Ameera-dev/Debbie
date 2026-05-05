import 'transaction_item_model.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.date,
    this.status = recordedStatus,
    this.title,
    this.notes,
    this.pendingUntil,
    this.emotion,
    this.latitude,
    this.longitude,
    this.locationLabel,
    required this.createdAt,
    this.items = const <TransactionItemModel>[],
    this.images = const <String>[],
  });

  static const recordedStatus = 'recorded';
  static const pendingStatus = 'pending';

  static const incomeType = 'income';
  static const expenseType = 'expense';
  static const savingType = 'saving';

  final String id;
  final String type; // 'income' | 'expense' | 'saving'
  final DateTime date;
  final String status;
  final String? title;
  final String? notes;
  final DateTime? pendingUntil;
  final String? emotion;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final DateTime createdAt;
  final List<TransactionItemModel> items;
  final List<String> images; // relative paths, ordered by sort_order

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasImages => images.isNotEmpty;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isSaving => type == 'saving';
  bool get isPending => status == pendingStatus;
  bool get isRecorded => status == recordedStatus;
  bool get isPendingReviewDue =>
      isPending &&
      pendingUntil != null &&
      !pendingUntil!.isAfter(DateTime.now());

  int get totalAmount => items.fold(0, (sum, item) => sum + item.amount);
  int get itemCount => items.length;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first.description;
    if (items.length == 2) {
      return '${items[0].description} & ${items[1].description}';
    }
    final remaining = items.length - 1;
    return '${items[0].description} & $remaining more';
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    DateTime? date,
    String? status,
    String? title,
    String? notes,
    DateTime? pendingUntil,
    String? emotion,
    double? latitude,
    double? longitude,
    String? locationLabel,
    DateTime? createdAt,
    List<TransactionItemModel>? items,
    List<String>? images,
    bool clearTitle = false,
    bool clearNotes = false,
    bool clearPendingUntil = false,
    bool clearEmotion = false,
    bool clearLocation = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      status: status ?? this.status,
      title: clearTitle ? null : (title ?? this.title),
      notes: clearNotes ? null : (notes ?? this.notes),
      pendingUntil: clearPendingUntil ? null : (pendingUntil ?? this.pendingUntil),
      emotion: clearEmotion ? null : (emotion ?? this.emotion),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationLabel: clearLocation ? null : (locationLabel ?? this.locationLabel),
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'date': date.toIso8601String(),
      'title': title,
      'notes': notes,
      'pending_until': pendingUntil?.toIso8601String(),
      'emotion': emotion,
      'latitude': latitude,
      'longitude': longitude,
      'location_label': locationLabel,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      status: map['status'] as String? ?? TransactionModel.recordedStatus,
      date: DateTime.parse(map['date'] as String),
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      pendingUntil: (map['pending_until'] as String?) != null
          ? DateTime.parse(map['pending_until'] as String)
          : null,
      emotion: map['emotion'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationLabel: map['location_label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      // images and items populated by the repository
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransactionModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
