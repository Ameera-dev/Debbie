/// Standardized tag taxonomy based on Plaid PFC, Mint, and Indonesian
/// personal finance conventions (Jago, Jenius, Finku).
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

  static const List<TagCategory> expenseCategories = [
    TagCategory(
      name: 'Makanan & Minuman',
      icon: '🍽️',
      forType: 'expense',
      tags: [
        'Groceries',
        'Dining Out',
        'Kafe & Minuman',
        'Food Delivery',
        'Jajan & Snack',
        'Warung & Warteg',
      ],
    ),
    TagCategory(
      name: 'Transportasi',
      icon: '🚗',
      forType: 'expense',
      tags: [
        'Ojol & Taksi Online',
        'BBM & Parkir',
        'Transportasi Umum',
        'Tol',
        'Servis Kendaraan',
        'Cicilan Kendaraan',
      ],
    ),
    TagCategory(
      name: 'Tagihan & Utilitas',
      icon: '🏠',
      forType: 'expense',
      tags: [
        'Listrik',
        'Air',
        'Internet & WiFi',
        'Pulsa & Paket Data',
        'Sewa & Kos',
        'TV & Streaming',
        'Gas',
      ],
    ),
    TagCategory(
      name: 'Belanja',
      icon: '🛍️',
      forType: 'expense',
      tags: [
        'Pakaian & Aksesoris',
        'Elektronik',
        'Perabot Rumah',
        'Perlengkapan Rumah',
        'Online Shopping',
        'Buku & Majalah',
        'Alat Olahraga',
      ],
    ),
    TagCategory(
      name: 'Kesehatan',
      icon: '💚',
      forType: 'expense',
      tags: [
        'Dokter & Klinik',
        'Obat & Apotek',
        'Rumah Sakit',
        'Gigi & Mata',
        'BPJS Kesehatan',
        'Gym & Olahraga',
        'Vitamin & Suplemen',
      ],
    ),
    TagCategory(
      name: 'Perawatan Diri',
      icon: '✨',
      forType: 'expense',
      tags: [
        'Toiletries',
        'Salon & Barbershop',
        'Kosmetik & Skincare',
        'Spa & Pijat',
        'Laundry',
      ],
    ),
    TagCategory(
      name: 'Hiburan',
      icon: '🎬',
      forType: 'expense',
      tags: [
        'Streaming (Netflix, Spotify)',
        'Bioskop & Konser',
        'Game',
        'Hobi',
        'Olahraga & Rekreasi',
      ],
    ),
    TagCategory(
      name: 'Pendidikan',
      icon: '📚',
      forType: 'expense',
      tags: [
        'Kursus & Pelatihan',
        'Buku Pelajaran',
        'SPP & Biaya Sekolah',
        'Seminar & Workshop',
        'Alat Belajar',
      ],
    ),
    TagCategory(
      name: 'Donasi & Sosial',
      icon: '🤲',
      forType: 'expense',
      tags: ['Zakat, Infak & Sedekah', 'Donasi', 'Arisan', 'Hadiah', 'THR'],
    ),
    TagCategory(
      name: 'Anak & Keluarga',
      icon: '👨‍👩‍👧',
      forType: 'expense',
      tags: [
        'Perlengkapan Bayi',
        'Biaya Pengasuhan',
        'Mainan & Aktivitas Anak',
        'Biaya Sekolah Anak',
      ],
    ),
    TagCategory(
      name: 'Perjalanan',
      icon: '✈️',
      forType: 'expense',
      tags: [
        'Tiket Pesawat & Kereta',
        'Hotel & Akomodasi',
        'Oleh-oleh',
        'Visa & Dokumen',
      ],
    ),
    TagCategory(
      name: 'Keuangan',
      icon: '💰',
      forType: 'expense',
      tags: [
        'Tabungan',
        'Investasi',
        'Asuransi Jiwa',
        'BPJS Ketenagakerjaan',
        'Cicilan Kartu Kredit',
        'Pinjaman Pribadi',
        'Pajak',
      ],
    ),
    TagCategory(
      name: 'Hewan Peliharaan',
      icon: '🐾',
      forType: 'expense',
      tags: ['Makanan Hewan', 'Dokter Hewan', 'Grooming Hewan'],
    ),
    TagCategory(
      name: 'Bisnis & Kerja',
      icon: '💼',
      forType: 'expense',
      tags: [
        'Perlengkapan Kantor',
        'Jasa & Konsultasi',
        'Biaya Administrasi',
        'Software & Tools',
        'Marketing',
      ],
    ),
    TagCategory(
      name: 'Lain-lain',
      icon: '📦',
      forType: 'expense',
      tags: ['Lain-lain'],
    ),
  ];

  static const List<TagCategory> incomeCategories = [
    TagCategory(
      name: 'Pendapatan',
      icon: '💵',
      forType: 'income',
      tags: [
        'Gaji & Upah',
        'Freelance & Proyek',
        'Bonus',
        'THR',
        'Komisi',
        'Lembur',
      ],
    ),
    TagCategory(
      name: 'Bisnis',
      icon: '🏪',
      forType: 'income',
      tags: ['Pendapatan Usaha', 'Penjualan Produk', 'Jasa'],
    ),
    TagCategory(
      name: 'Investasi',
      icon: '📈',
      forType: 'income',
      tags: [
        'Dividen',
        'Bunga Tabungan & Deposito',
        'Keuntungan Saham',
        'Hasil Reksa Dana',
        'Hasil Crypto',
      ],
    ),
    TagCategory(
      name: 'Properti',
      icon: '🏡',
      forType: 'income',
      tags: ['Uang Sewa', 'Hasil Jual Properti'],
    ),
    TagCategory(
      name: 'Transfer & Lainnya',
      icon: '🔄',
      forType: 'income',
      tags: [
        'Transfer Masuk',
        'Pengembalian Dana',
        'Hadiah & Pemberian',
        'Subsidi & Bantuan',
        'Arisan Cair',
        'Lain-lain',
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
