class LanguageDetector {
  const LanguageDetector();

  /// Detects the ISO 639-1 language code of the given input text.
  /// Supported: 'en', 'si', 'ta', 'hi', 'zh', 'es', 'fr', 'de'.
  String detectLanguage(String text) {
    if (text.trim().isEmpty) return 'unknown';

    int sinhalaCount = 0;
    int tamilCount = 0;
    int devanagariCount = 0;
    int hanCount = 0;
    int latinCount = 0;

    for (final rune in text.runes) {
      if (rune >= 0x0D80 && rune <= 0x0DFF) {
        sinhalaCount++;
      } else if (rune >= 0x0B80 && rune <= 0x0BFF) {
        tamilCount++;
      } else if (rune >= 0x0900 && rune <= 0x097F) {
        devanagariCount++;
      } else if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
                 (rune >= 0x3400 && rune <= 0x4DBF)) {
        hanCount++;
      } else if ((rune >= 0x0041 && rune <= 0x005A) ||
                 (rune >= 0x0061 && rune <= 0x007A) ||
                 (rune >= 0x00C0 && rune <= 0x00FF)) {
        latinCount++;
      }
    }

    final total = text.runes.length;
    if (total == 0) return 'unknown';

    if (sinhalaCount > 0 && sinhalaCount >= total * 0.3) return 'si';
    if (tamilCount > 0 && tamilCount >= total * 0.3) return 'ta';
    if (devanagariCount > 0 && devanagariCount >= total * 0.3) return 'hi';
    if (hanCount > 0 && hanCount >= total * 0.3) return 'zh';

    if (latinCount > 0 && latinCount >= total * 0.3) {
      final lower = text.toLowerCase();

      // German accent & keyword detection
      if (lower.contains('ä') || lower.contains('ö') || lower.contains('ü') || lower.contains('ß') ||
          RegExp(r'\b(der|die|das|des|den|dem|und|ist|nicht|eingang|haupteingang|ausgang|schalter|museum|museums)\b').hasMatch(lower)) {
        return 'de';
      }

      // Spanish accent & keyword detection
      if (lower.contains('ñ') || lower.contains('á') || lower.contains('í') || lower.contains('ó') || lower.contains('ú') || lower.contains('¿') || lower.contains('¡') ||
          RegExp(r'\b(el|los|las|entrada|salida|boletos|museo|cueva)\b').hasMatch(lower)) {
        return 'es';
      }

      // French accent & keyword detection
      if (lower.contains('é') || lower.contains('è') || lower.contains('ê') || lower.contains('ç') || lower.contains('à') ||
          RegExp(r'\b(le|les|est|entrée|sortie|billetterie|musée)\b').hasMatch(lower)) {
        return 'fr';
      }

      return 'en';
    }

    return 'en';
  }
}
