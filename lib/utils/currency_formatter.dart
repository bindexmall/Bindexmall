// ============================================================================
// UTIL: CurrencyFormatter
// ============================================================================
// Helper format angka jadi format Rupiah (Rp 1.000.000, dsb).
//
// Catatan:
//  - Dipakai di banyak screen/widget untuk menampilkan harga produk & total.
//  - Ada juga class serupa CurrencyFormatter di dalam product_detail_screen.dart —
//  -   cek dua-duanya sebelum mengubah format supaya konsisten di seluruh app.
// ============================================================================

import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format double amount to Rupiah currency string
  /// Example: 52000.0 -> "Rp 52.000"
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Format integer amount to Rupiah currency string
  /// Example: 52000 -> "Rp 52.000"
  static String formatInt(int amount) {
    return _formatter.format(amount);
  }

  /// Format to Rupiah without symbol
  /// Example: 52000.0 -> "52.000"
  static String formatWithoutSymbol(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  /// Parse Rupiah string to double
  /// Example: "Rp 52.000" -> 52000.0
  static double parse(String rupiahString) {
    final cleanString = rupiahString
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleanString) ?? 0.0;
  }

  /// Format with custom symbol
  static String formatCustom(double amount, {String symbol = 'Rp '}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: symbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
