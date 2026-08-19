class OcrTextProcessor {
  const OcrTextProcessor();

  // Compiled once and reused \u2014 building these RegExp objects fresh on every
  // normalize() call (which runs many times per captured photo) was a
  // measurable source of UI-thread jank right after the shutter press.
  static final RegExp _newlineRegex = RegExp(r'[\r\n]+');
  static final RegExp _noiseRegex =
      RegExp(r'[^\p{L}\p{N}\p{M}\s\u200D]+', unicode: true);
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _zwjRepeatRegex = RegExp(r'\u200D+');
  static final RegExp _zwjLeadingRegex = RegExp(r'(?<=\s|^)\u200D+');
  static final RegExp _zwjTrailingRegex = RegExp(r'\u200D+(?=\s|$)');
  static final RegExp _kombuvaRegex = RegExp(r'(\u0DD9)([\u0D9A-\u0DC6])');
  static final RegExp _alLakunaRegex = RegExp(r'\u0DCA+');

  /// Cleans and normalizes raw OCR text for domain matching.
  String normalize(String rawText) {
    if (rawText.trim().isEmpty) return '';

    // 1. Replace newlines and carriage returns with spaces
    String text = rawText.replaceAll(_newlineRegex, ' ');

    // 2. Perform Sinhala Unicode normalization if text contains Sinhala script
    if (containsSinhala(text)) {
      text = normalizeSinhala(text);
    } else {
      // Convert Latin text to lowercase for consistent comparison
      text = text.toLowerCase();
    }

    // 3. Remove OCR artifact noise symbols while preserving Unicode letters (\p{L}), numbers (\p{N}), combining marks (\p{M}) & ZWJ (\u200D)
    text = text.replaceAll(_noiseRegex, ' ');

    // 4. Collapse multiple spaces into a single space
    text = text.replaceAll(_multiSpaceRegex, ' ');

    // 5. Trim leading and trailing whitespace
    return text.trim();
  }

  /// Checks if text contains Sinhala script runes (U+0D80 to U+0DFF).
  bool containsSinhala(String text) {
    for (final rune in text.runes) {
      if (rune >= 0x0D80 && rune <= 0x0DFF) return true;
    }
    return false;
  }

  /// Dedicated Sinhala Unicode Normalizer:
  /// - Removes invalid zero-width characters except semantic ZWJ (\u200D)
  /// - Normalizes Sinhala vowel sign sequence order and diacritics
  /// - Standardizes redundant whitespace
  String normalizeSinhala(String rawSinhala) {
    if (rawSinhala.isEmpty) return '';

    String s = rawSinhala;

    // Remove zero-width non-joiners (\u200C) and stray control characters
    s = s.replaceAll('\u200C', '');

    // Normalize multiple consecutive Zero-Width Joiners to a single ZWJ
    s = s.replaceAll(_zwjRepeatRegex, '\u200D');

    // Remove ZWJ if it appears at start or end of a word without consonants
    s = s.replaceAll(_zwjLeadingRegex, '');
    s = s.replaceAll(_zwjTrailingRegex, '');

    // Normalize Sinhala kombuva (\u0DD9) ordering if placed before consonant in raw OCR string
    // In Unicode, Kombuva (\u0DD9) follows consonant. Fix visual-order OCR artifacts:
    s = s.replaceAllMapped(
      _kombuvaRegex,
      (match) => '${match.group(2)}${match.group(1)}',
    );

    // Normalize redundant Al-lakuna (\u0DCA) diacritic combinations
    s = s.replaceAll(_alLakunaRegex, '\u0DCA');

    return s;
  }

  /// Extracts multiple logical text lines from multiline OCR blocks.
  List<String> extractLines(String rawText) {
    if (rawText.trim().isEmpty) return const [];
    return rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

