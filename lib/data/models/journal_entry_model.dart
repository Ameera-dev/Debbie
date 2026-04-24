class JournalEntryModel {
  const JournalEntryModel({
    required this.id,
    required this.content,
    this.mood,
    this.aiResponse,
    this.entryType = legacyEntryType,
    this.periodStart,
    required this.date,
    required this.createdAt,
  });

  static const weeklyCheckInType = 'weekly_check_in';
  static const moneyStoryType = 'money_story';
  static const legacyEntryType = 'legacy_entry';

  final String id;
  final String content;
  final String? mood; // 'grateful' | 'reflective' | 'uncertain' | 'motivated'
  final String? aiResponse;
  final String entryType;
  final DateTime? periodStart;
  final DateTime date;
  final DateTime createdAt;

  bool get isWeeklyCheckIn => entryType == weeklyCheckInType;
  bool get isMoneyStory => entryType == moneyStoryType;
  bool get isLegacyEntry => entryType == legacyEntryType;

  String get moodEmoji {
    switch (mood) {
      case 'grateful':
        return '🙏';
      case 'reflective':
        return '🌊';
      case 'uncertain':
        return '🌫️';
      case 'motivated':
        return '⚡';
      default:
        return '📝';
    }
  }

  JournalEntryModel copyWith({
    String? id,
    String? content,
    String? mood,
    String? aiResponse,
    String? entryType,
    DateTime? periodStart,
    DateTime? date,
    DateTime? createdAt,
    bool clearMood = false,
    bool clearAiResponse = false,
    bool clearPeriodStart = false,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      content: content ?? this.content,
      mood: clearMood ? null : (mood ?? this.mood),
      aiResponse: clearAiResponse ? null : (aiResponse ?? this.aiResponse),
      entryType: entryType ?? this.entryType,
      periodStart: clearPeriodStart ? null : (periodStart ?? this.periodStart),
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'mood': mood,
      'ai_response': aiResponse,
      'entry_type': entryType,
      'period_start': periodStart?.toIso8601String(),
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory JournalEntryModel.fromMap(Map<String, dynamic> map) {
    return JournalEntryModel(
      id: map['id'] as String,
      content: map['content'] as String,
      mood: map['mood'] as String?,
      aiResponse: map['ai_response'] as String?,
      entryType:
          map['entry_type'] as String? ?? JournalEntryModel.legacyEntryType,
      periodStart: (map['period_start'] as String?) != null
          ? DateTime.parse(map['period_start'] as String)
          : null,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JournalEntryModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
