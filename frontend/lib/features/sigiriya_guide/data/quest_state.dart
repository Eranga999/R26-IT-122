// lib/features/sigiriya_guide/data/quest_state.dart
//
// Singleton ChangeNotifier that stores in-session quest progress.
// No external packages required – works with plain AnimatedBuilder/ListenableBuilder.

import 'package:flutter/foundation.dart';
import 'quiz_translations.dart';

/// Tracks progress for all four quest stages.
class QuestProgress extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final QuestProgress instance = QuestProgress._();
  QuestProgress._();

  // ── Raw state ──────────────────────────────────────────────────────────────
  final Set<String> _visitedLocationIds = {};
  int _bestQuizScore = 0;
  int _quizTotal = 10;
  final Set<QuizLanguage> _languagesTried = {QuizLanguage.english};

  // ── Quest 1 · Explorer · Visit 5 locations ─────────────────────────────────
  static const int explorerTarget = 5;
  int get explorerCount => _visitedLocationIds.length.clamp(0, explorerTarget);
  double get explorerProgress => explorerCount / explorerTarget;
  bool get explorerComplete => _visitedLocationIds.length >= explorerTarget;

  // ── Quest 2 · Scholar · Score 7 / 10 on the quiz ──────────────────────────
  static const int scholarTarget = 7;
  int get scholarBest => _bestQuizScore;
  int get scholarTotal => _quizTotal;
  double get scholarProgress => (_bestQuizScore / scholarTarget).clamp(0.0, 1.0);
  bool get scholarComplete => _bestQuizScore >= scholarTarget;

  // ── Quest 3 · Polyglot · Try quiz in 3 languages ──────────────────────────
  static const int polyglotTarget = 3;
  int get polyglotCount => _languagesTried.length.clamp(0, polyglotTarget);
  double get polyglotProgress => polyglotCount / polyglotTarget;
  bool get polyglotComplete => _languagesTried.length >= polyglotTarget;
  Set<QuizLanguage> get languagesTried => Set.unmodifiable(_languagesTried);

  // ── Quest 4 · Master · All three above complete ────────────────────────────
  int get masterDone =>
      (explorerComplete ? 1 : 0) +
      (scholarComplete ? 1 : 0) +
      (polyglotComplete ? 1 : 0);
  double get masterProgress => masterDone / 3.0;
  bool get masterComplete => masterDone == 3;

  // ── Total badges earned (for header summary) ───────────────────────────────
  int get totalBadges =>
      (explorerComplete ? 1 : 0) +
      (scholarComplete ? 1 : 0) +
      (polyglotComplete ? 1 : 0) +
      (masterComplete ? 1 : 0);

  // ── Mutators ───────────────────────────────────────────────────────────────

  /// Called when a user opens a location detail page.
  void markLocationVisited(String locationId) {
    if (_visitedLocationIds.add(locationId)) notifyListeners();
  }

  /// Called at the end of every completed quiz run.
  void updateQuizScore(int score, int total) {
    _quizTotal = total;
    if (score > _bestQuizScore) {
      _bestQuizScore = score;
      notifyListeners();
    }
  }

  /// Called whenever the quiz language chip is tapped.
  void markLanguageTried(QuizLanguage lang) {
    if (_languagesTried.add(lang)) notifyListeners();
  }

  /// Resets all progress (useful for debug / restart).
  void reset() {
    _visitedLocationIds.clear();
    _bestQuizScore = 0;
    _quizTotal = 10;
    _languagesTried
      ..clear()
      ..add(QuizLanguage.english);
    notifyListeners();
  }
}
