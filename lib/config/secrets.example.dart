// ============================================================================
// CONFIG: Secrets (TEMPLATE — file ini AMAN buat di-commit ke git)
// ============================================================================
// Ini cuma contoh struktur. Buat pakai:
//   1. Copy file ini jadi secrets.dart (di folder yang sama)
//   2. Isi semua value 'ISI_DI_SINI' dengan key asli
//   3. secrets.dart TIDAK boleh ikut ke-commit (sudah di .gitignore)
//
// Lihat secrets.dart untuk catatan tingkat risiko tiap key.
// ============================================================================

class Secrets {
  static const String wooCommerceConsumerKey = 'ISI_DI_SINI';
  static const String wooCommerceConsumerSecret = 'ISI_DI_SINI';

  static const String midtransServerKey = 'ISI_DI_SINI';
  static const String midtransClientKey = 'ISI_DI_SINI';

  static const String rajaOngkirApiKey = 'ISI_DI_SINI';

  static const String cloudinaryApiKey = 'ISI_DI_SINI';
  static const String cloudinaryApiSecret = 'ISI_DI_SINI';
}
