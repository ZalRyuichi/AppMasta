/// Konfigurasi Gemini API buat otak si Bocchi.
///
/// Model default: gemini-2.5-flash — ada di free tier Google AI Studio
/// (kuota harian, tanpa kartu kredit), dan support function calling asli
/// buat trigger "buka fitur" (jauh lebih akurat dibanding hack regex tag).
///
/// Catatan: "gratis" di sini artinya free tier Google (ada kuota rate-limit
/// harian, bukan benar-benar tanpa batas) — kalau kena limit, Bocchi bakal
/// kasih pesan error yang jelas, bukan crash diam-diam.
class GeminiConfig {
  static const String apiKey = 'AIzaSyC3AQQteDPp6zTIPUrBbVBsKMkEfJ7ORo0';
  static const String model = 'gemini-2.5-flash';

  static Uri get endpoint => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
}
