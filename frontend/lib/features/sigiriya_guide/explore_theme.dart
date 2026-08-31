import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Colour rule for **every screen reachable from the app's "Explore" button**
/// (the Sigiriya guide flow: selection → results → hub → experiences →
/// location detail → gamified quiz → galleries).
///
/// It maps that flow onto the same heritage palette [AppTheme] the rest of the
/// app uses, so tapping Explore no longer drops the user into a dark-themed
/// island. Every Explore screen should pull its colours from here rather than
/// hard-coding hex values or reading `Theme.of(context).colorScheme`.
class ExploreTheme {
  ExploreTheme._();

  /// Heritage gold — fills, pills, active state, focus rings.
  static const Color accent = AppTheme.secondary;

  /// Terracotta — accent text / links / icons on a light surface
  /// (gold has too little contrast on white for text-sized elements).
  static const Color accentText = AppTheme.primary;

  /// Warm parchment — page background.
  static const Color bg = AppTheme.surface;

  /// Cards, inputs, sheets, menus.
  static const Color card = Colors.white;

  /// Soft parchment hairline border.
  static const Color border = Color(0xFFEADFCE);

  /// Deep espresso — headings / primary text.
  static const Color text = AppTheme.textBase;

  /// Muted brown — secondary / caption text.
  static const Color textSoft = Color(0xFF6D4C41);

  /// Body copy (matches `AppTheme` `bodyMedium`).
  static const Color body = Color(0xFF4E342E);

  /// Terracotta — app bars. Always pair with a white foreground.
  static const Color bar = AppTheme.primary;

  /// Positive / success (correct quiz answer, "complete").
  static const Color success = Color(0xFF2E7D32);

  /// Secondary category accent (quiz / gamified layer).
  static const Color info = Color(0xFF3F6DB5);

  /// Skeleton-shimmer gradient stops on the light surface.
  static const Color shimmerBase = Color(0xFFEDE3D3);
  static const Color shimmerHi = Color(0xFFF8F1E6);
}
