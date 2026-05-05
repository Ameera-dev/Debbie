/// Standardized tag taxonomy based on Plaid PFC and Mint conventions,
/// adapted for Indonesian personal finance habits (presented in English).
///
/// Structure: TagCategory → List of tag names (freeform strings stored in DB).
class TagCategory {
  const TagCategory({
    required this.name,
    required this.icon,
    required this.tags,
    required this.forType, // 'expense' | 'income' | 'both'
  });

  final String name;
  final String icon;
  final List<String> tags;
  final String forType;
}

class DefaultTags {
  DefaultTags._();

  static const String fallbackTag = 'Other';

  static const List<TagCategory> expenseCategories = [
    TagCategory(
      name: 'Food & Drink',
      icon: '🍽️',
      forType: 'expense',
      tags: [
        'Groceries',
        'Dining Out',
        'Cafes & Drinks',
        'Food Delivery',
        'Snacks',
        'Local Eateries',
      ],
    ),
    TagCategory(
      name: 'Transportation',
      icon: '🚗',
      forType: 'expense',
      tags: [
        'Ride-hailing',
        'Fuel & Parking',
        'Public Transit',
        'Tolls',
        'Vehicle Service',
        'Vehicle Loan',
      ],
    ),
    TagCategory(
      name: 'Bills & Utilities',
      icon: '🏠',
      forType: 'expense',
      tags: [
        'Electricity',
        'Water',
        'Internet & WiFi',
        'Mobile & Data',
        'Rent & Housing',
        'TV & Streaming',
        'Gas',
      ],
    ),
    TagCategory(
      name: 'Shopping',
      icon: '🛍️',
      forType: 'expense',
      tags: [
        'Clothing & Accessories',
        'Electronics',
        'Furniture',
        'Household Supplies',
        'Online Shopping',
        'Books & Magazines',
        'Sports Gear',
      ],
    ),
    TagCategory(
      name: 'Health',
      icon: '💚',
      forType: 'expense',
      tags: [
        'Doctor & Clinic',
        'Pharmacy',
        'Hospital',
        'Dental & Vision',
        'Health Insurance',
        'Gym & Fitness',
        'Vitamins & Supplements',
      ],
    ),
    TagCategory(
      name: 'Personal Care',
      icon: '✨',
      forType: 'expense',
      tags: [
        'Toiletries',
        'Salon & Barber',
        'Cosmetics & Skincare',
        'Spa & Massage',
        'Laundry',
      ],
    ),
    TagCategory(
      name: 'Entertainment',
      icon: '🎬',
      forType: 'expense',
      tags: [
        'Streaming (Netflix, Spotify)',
        'Movies & Concerts',
        'Games',
        'Hobbies',
        'Sports & Recreation',
      ],
    ),
    TagCategory(
      name: 'Education',
      icon: '📚',
      forType: 'expense',
      tags: [
        'Courses & Training',
        'Textbooks',
        'Tuition Fees',
        'Seminars & Workshops',
        'Learning Supplies',
      ],
    ),
    TagCategory(
      name: 'Giving & Social',
      icon: '🤲',
      forType: 'expense',
      tags: ['Charity & Almsgiving', 'Donations', 'Community Pool', 'Gifts', 'Holiday Bonus'],
    ),
    TagCategory(
      name: 'Family & Kids',
      icon: '👨‍👩‍👧',
      forType: 'expense',
      tags: [
        'Baby Supplies',
        'Childcare',
        'Toys & Activities',
        'School Fees',
      ],
    ),
    TagCategory(
      name: 'Travel',
      icon: '✈️',
      forType: 'expense',
      tags: [
        'Flights & Trains',
        'Hotels & Lodging',
        'Souvenirs',
        'Visa & Documents',
      ],
    ),
    TagCategory(
      name: 'Finance',
      icon: '💰',
      forType: 'expense',
      tags: [
        'Savings',
        'Investments',
        'Life Insurance',
        'Social Security',
        'Credit Card Payment',
        'Personal Loan',
        'Taxes',
      ],
    ),
    TagCategory(
      name: 'Pets',
      icon: '🐾',
      forType: 'expense',
      tags: ['Pet Food', 'Vet', 'Pet Grooming'],
    ),
    TagCategory(
      name: 'Business & Work',
      icon: '💼',
      forType: 'expense',
      tags: [
        'Office Supplies',
        'Services & Consulting',
        'Admin Fees',
        'Software & Tools',
        'Marketing',
      ],
    ),
    TagCategory(
      name: 'Other',
      icon: '📦',
      forType: 'expense',
      tags: ['Other'],
    ),
  ];

  static const List<TagCategory> incomeCategories = [
    TagCategory(
      name: 'Earnings',
      icon: '💵',
      forType: 'income',
      tags: [
        'Salary & Wages',
        'Freelance & Projects',
        'Bonus',
        'Holiday Bonus',
        'Commission',
        'Overtime',
      ],
    ),
    TagCategory(
      name: 'Business',
      icon: '🏪',
      forType: 'income',
      tags: ['Business Income', 'Product Sales', 'Services'],
    ),
    TagCategory(
      name: 'Investments',
      icon: '📈',
      forType: 'income',
      tags: [
        'Dividends',
        'Savings & Deposit Interest',
        'Stock Gains',
        'Mutual Fund Returns',
        'Crypto Gains',
      ],
    ),
    TagCategory(
      name: 'Property',
      icon: '🏡',
      forType: 'income',
      tags: ['Rental Income', 'Property Sale'],
    ),
    TagCategory(
      name: 'Transfers & Other',
      icon: '🔄',
      forType: 'income',
      tags: [
        'Incoming Transfer',
        'Refunds',
        'Gifts Received',
        'Subsidies & Aid',
        'Pool Payout',
        'Other',
      ],
    ),
  ];

  /// Returns all tags for a given transaction type as a flat list.
  static List<String> flatTagsFor(String type) {
    final cats = type == 'income' ? incomeCategories : expenseCategories;
    return cats.expand((c) => c.tags).toList();
  }

  /// Returns categories filtered for a given type.
  static List<TagCategory> categoriesFor(String type) {
    return type == 'income' ? incomeCategories : expenseCategories;
  }

  /// Find which parent category a tag belongs to.
  static TagCategory? parentOf(String tag, String type) {
    final cats = categoriesFor(type);
    for (final cat in cats) {
      if (cat.tags.contains(tag)) return cat;
    }
    return null;
  }
}
