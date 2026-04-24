import '../../data/models/value_model.dart';

class DefaultValues {
  DefaultValues._();

  static const List<Map<String, String>> presets = [
    {
      'name': 'Essentials',
      'icon': '🏠',
      'description': 'Keeping daily life running smoothly',
      'detail':
          'Rent, utilities, groceries, transport, phone bill, subscriptions you rely on — the foundation that keeps everything else possible.',
      'suggestion': '30–50%',
    },
    {
      'name': 'Family',
      'icon': '🏡',
      'description': 'Nurturing the people closest to you',
      'detail':
          'Family meals, childcare, gifts for loved ones, home improvements, family outings, education for children — strengthening your inner circle.',
      'suggestion': '10–20%',
    },
    {
      'name': 'Health',
      'icon': '💚',
      'description': 'Taking care of your mind and body',
      'detail':
          'Gym membership, nutritious food, medical checkups, therapy, vitamins, wellness apps, sports — prioritizing your physical and mental well-being.',
      'suggestion': '5–15%',
    },
    {
      'name': 'Growth',
      'icon': '🌱',
      'description': 'Learning and becoming your best self',
      'detail':
          'Online courses, books, coaching, certifications, conferences, podcasts, workshops — investing in your skills, career, and personal development.',
      'suggestion': '5–10%',
    },
    {
      'name': 'Security',
      'icon': '🛡️',
      'description': 'Building stability and financial independence',
      'detail':
          'Savings, emergency fund, insurance, investments, debt repayment, retirement fund — creating a foundation of freedom and peace of mind.',
      'suggestion': '10–20%',
    },
    {
      'name': 'Joy',
      'icon': '✨',
      'description': 'What makes life fun and fulfilling',
      'detail':
          'Hobbies, travel, dining out, entertainment, creative projects, art supplies, music, gaming, weekend trips — the experiences that light you up.',
      'suggestion': '5–15%',
    },
    {
      'name': 'Connection',
      'icon': '🤝',
      'description': 'Relationships, community, and giving back',
      'detail':
          'Hanging out with friends, social events, gifts, donations, charity, memberships, coworking, community projects — the people and causes you care about.',
      'suggestion': '5–10%',
    },
  ];

  /// Returns a list of ValueModel presets with placeholder IDs.
  /// IDs will be replaced with UUID v4 when saved.
  static List<ValueModel> asModels() {
    return presets.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return ValueModel(
        id: 'preset_$index',
        name: data['name']!,
        icon: data['icon']!,
        color: ValueColors.list[index % ValueColors.list.length],
        priority: index,
        createdAt: DateTime.now(),
      );
    }).toList();
  }
}

class ValueColors {
  ValueColors._();

  static const List<String> list = [
    '#4A7C8F', // Ocean blue (Essentials)
    '#C9A462', // Sand gold (Family)
    '#5A9E7A', // Seafoam (Health)
    '#7B6BAF', // Twilight purple (Growth)
    '#3D8B8B', // Deep teal (Security)
    '#CF7B5F', // Coral (Joy)
    '#6B8EAE', // Sky blue (Connection)
  ];
}
