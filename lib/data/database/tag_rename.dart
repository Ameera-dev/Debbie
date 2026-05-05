import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'tables.dart';

/// One-shot mapping from the legacy Indonesian tag taxonomy to the
/// current English taxonomy in [DefaultTags]. Applied both as a DB
/// migration on app start and inside the Drive restore path so older
/// backup ZIPs come back normalized.
const Map<String, String> tagRenameMap = {
  // Expense — Food & Drink
  'Kafe & Minuman': 'Cafes & Drinks',
  'Jajan & Snack': 'Snacks',
  'Warung & Warteg': 'Local Eateries',

  // Expense — Transportation
  'Ojol & Taksi Online': 'Ride-hailing',
  'BBM & Parkir': 'Fuel & Parking',
  'Transportasi Umum': 'Public Transit',
  'Tol': 'Tolls',
  'Servis Kendaraan': 'Vehicle Service',
  'Cicilan Kendaraan': 'Vehicle Loan',

  // Expense — Bills & Utilities
  'Listrik': 'Electricity',
  'Air': 'Water',
  'Pulsa & Paket Data': 'Mobile & Data',
  'Sewa & Kos': 'Rent & Housing',

  // Expense — Shopping
  'Pakaian & Aksesoris': 'Clothing & Accessories',
  'Elektronik': 'Electronics',
  'Perabot Rumah': 'Furniture',
  'Perlengkapan Rumah': 'Household Supplies',
  'Buku & Majalah': 'Books & Magazines',
  'Alat Olahraga': 'Sports Gear',

  // Expense — Health
  'Dokter & Klinik': 'Doctor & Clinic',
  'Obat & Apotek': 'Pharmacy',
  'Rumah Sakit': 'Hospital',
  'Gigi & Mata': 'Dental & Vision',
  'BPJS Kesehatan': 'Health Insurance',
  'Gym & Olahraga': 'Gym & Fitness',
  'Vitamin & Suplemen': 'Vitamins & Supplements',

  // Expense — Personal Care
  'Salon & Barbershop': 'Salon & Barber',
  'Kosmetik & Skincare': 'Cosmetics & Skincare',
  'Spa & Pijat': 'Spa & Massage',

  // Expense — Entertainment
  'Bioskop & Konser': 'Movies & Concerts',
  'Game': 'Games',
  'Hobi': 'Hobbies',
  'Olahraga & Rekreasi': 'Sports & Recreation',

  // Expense — Education
  'Kursus & Pelatihan': 'Courses & Training',
  'Buku Pelajaran': 'Textbooks',
  'SPP & Biaya Sekolah': 'Tuition Fees',
  'Seminar & Workshop': 'Seminars & Workshops',
  'Alat Belajar': 'Learning Supplies',

  // Expense — Giving & Social
  'Zakat, Infak & Sedekah': 'Charity & Almsgiving',
  'Donasi': 'Donations',
  'Arisan': 'Community Pool',
  'Hadiah': 'Gifts',
  'THR': 'Holiday Bonus',

  // Expense — Family & Kids
  'Perlengkapan Bayi': 'Baby Supplies',
  'Biaya Pengasuhan': 'Childcare',
  'Mainan & Aktivitas Anak': 'Toys & Activities',
  'Biaya Sekolah Anak': 'School Fees',

  // Expense — Travel
  'Tiket Pesawat & Kereta': 'Flights & Trains',
  'Hotel & Akomodasi': 'Hotels & Lodging',
  'Oleh-oleh': 'Souvenirs',
  'Visa & Dokumen': 'Visa & Documents',

  // Expense — Finance
  'Tabungan': 'Savings',
  'Investasi': 'Investments',
  'Asuransi Jiwa': 'Life Insurance',
  'BPJS Ketenagakerjaan': 'Social Security',
  'Cicilan Kartu Kredit': 'Credit Card Payment',
  'Pinjaman Pribadi': 'Personal Loan',
  'Pajak': 'Taxes',

  // Expense — Pets
  'Makanan Hewan': 'Pet Food',
  'Dokter Hewan': 'Vet',
  'Grooming Hewan': 'Pet Grooming',

  // Expense — Business & Work
  'Perlengkapan Kantor': 'Office Supplies',
  'Jasa & Konsultasi': 'Services & Consulting',
  'Biaya Administrasi': 'Admin Fees',

  // Expense / Income — fallback
  'Lain-lain': 'Other',

  // Income — Earnings
  'Gaji & Upah': 'Salary & Wages',
  'Freelance & Proyek': 'Freelance & Projects',
  'Komisi': 'Commission',
  'Lembur': 'Overtime',

  // Income — Business
  'Pendapatan Usaha': 'Business Income',
  'Penjualan Produk': 'Product Sales',
  'Jasa': 'Services',

  // Income — Investments
  'Dividen': 'Dividends',
  'Bunga Tabungan & Deposito': 'Savings & Deposit Interest',
  'Keuntungan Saham': 'Stock Gains',
  'Hasil Reksa Dana': 'Mutual Fund Returns',
  'Hasil Crypto': 'Crypto Gains',

  // Income — Property
  'Uang Sewa': 'Rental Income',
  'Hasil Jual Properti': 'Property Sale',

  // Income — Transfers & Other
  'Transfer Masuk': 'Incoming Transfer',
  'Pengembalian Dana': 'Refunds',
  'Hadiah & Pemberian': 'Gifts Received',
  'Subsidi & Bantuan': 'Subsidies & Aid',
  'Arisan Cair': 'Pool Payout',
};

String renameTag(String tag) => tagRenameMap[tag] ?? tag;

/// Rewrites legacy Indonesian tag strings to their English equivalents
/// across [Tables.transactionItems] and [Tables.recurringExpenses].
/// Safe to run multiple times — already-English tags are left alone.
Future<void> renameLegacyTags(DatabaseExecutor db) async {
  // transaction_items.tags is a JSON array string.
  final itemRows = await db.query(
    Tables.transactionItems,
    columns: ['id', 'tags'],
    where: 'tags IS NOT NULL AND tags != ?',
    whereArgs: ['[]'],
  );
  for (final row in itemRows) {
    final raw = row['tags'] as String?;
    if (raw == null || raw.isEmpty) continue;
    final decoded = jsonDecode(raw);
    if (decoded is! List) continue;
    var changed = false;
    final mapped = decoded.map((tag) {
      if (tag is! String) return tag;
      final next = tagRenameMap[tag];
      if (next != null && next != tag) {
        changed = true;
        return next;
      }
      return tag;
    }).toList();
    if (!changed) continue;
    await db.update(
      Tables.transactionItems,
      {'tags': jsonEncode(mapped)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  // recurring_expenses.category is a single tag string.
  final recurringRows = await db.query(
    Tables.recurringExpenses,
    columns: ['id', 'category'],
    where: 'category IS NOT NULL',
  );
  for (final row in recurringRows) {
    final current = row['category'] as String?;
    if (current == null) continue;
    final next = tagRenameMap[current];
    if (next == null || next == current) continue;
    await db.update(
      Tables.recurringExpenses,
      {'category': next},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}
