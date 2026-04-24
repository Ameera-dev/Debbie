import 'transaction_item_model.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.date,
    this.status = recordedStatus,
    this.title,
    this.notes,
    this.imagePath,
    this.pendingUntil,
    this.emotion,
    required this.createdAt,
    this.items = const <TransactionItemModel>[],
  });

  static const recordedStatus = 'recorded';
  static const pendingStatus = 'pending';

  final String id;
  final String type; // 'income' | 'expense'
  final DateTime date;
  final String status;
  final String? title; // user-given label for the transaction
  final String? notes;
  final String? imagePath; // relative path to attached image
  final DateTime? pendingUntil;
  final String? emotion;
  final DateTime createdAt;
  final List<TransactionItemModel> items;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isPending => status == pendingStatus;
  bool get isRecorded => status == recordedStatus;
  bool get isPendingReviewDue =>
      isPending &&
      pendingUntil != null &&
      !pendingUntil!.isAfter(DateTime.now());

  /// Sum of all item amounts.
  int get totalAmount => items.fold(0, (sum, item) => sum + item.amount);

  int get itemCount => items.length;

  /// Display name: title if set, otherwise auto-generated from items.
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
    String? imagePath,
    DateTime? pendingUntil,
    String? emotion,
    DateTime? createdAt,
    List<TransactionItemModel>? items,
    bool clearTitle = false,
    bool clearNotes = false,
    bool clearImagePath = false,
    bool clearPendingUntil = false,
    bool clearEmotion = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      status: status ?? this.status,
      title: clearTitle ? null : (title ?? this.title),
      notes: clearNotes ? null : (notes ?? this.notes),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      pendingUntil: clearPendingUntil
          ? null
          : (pendingUntil ?? this.pendingUntil),
      emotion: clearEmotion ? null : (emotion ?? this.emotion),
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  /// Serializes session-level fields only (not items).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'date': date.toIso8601String(),
      'title': title,
      'notes': notes,
      'image_path': imagePath,
      'pending_until': pendingUntil?.toIso8601String(),
      'emotion': emotion,
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
      imagePath: map['image_path'] as String?,
      pendingUntil: (map['pending_until'] as String?) != null
          ? DateTime.parse(map['pending_until'] as String)
          : null,
      emotion: map['emotion'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      // items populated by the repository after a join/second query
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransactionModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
