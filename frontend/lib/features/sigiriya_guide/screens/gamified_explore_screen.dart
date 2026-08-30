import 'package:flutter/material.dart';
import '../data/quest_state.dart';
import '../data/quiz_translations.dart';

class GamifiedExploreScreen extends StatefulWidget {
  const GamifiedExploreScreen({super.key});

  @override
  State<GamifiedExploreScreen> createState() => _GamifiedExploreScreenState();
}

class _GamifiedExploreScreenState extends State<GamifiedExploreScreen> {
  QuizLanguage _language = QuizLanguage.english;
  List<QuizQuestionData> get _questions => getQuizQuestions(_language);

  int _currentIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;

  QuizQuestionData get _currentQuestion => _questions[_currentIndex];

  bool get _isFinished => _currentIndex >= _questions.length;

  void _selectAnswer(int index) {
    if (_answered || _isFinished) return;

    final question = _currentQuestion;
    final isCorrect = index == question.correctIndex;

    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (isCorrect) _score += 1;
    });
  }

  void _nextQuestion() {
    if (!_answered) return;

    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex += 1;
        _selectedIndex = null;
        _answered = false;
      } else {
        // Quiz finished — persist best score to quest tracker
        QuestProgress.instance.updateQuizScore(_score, _questions.length);
        _currentIndex = _questions.length;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _selectedIndex = null;
      _answered = false;
    });
  }

  void _changeLanguage(QuizLanguage lang) {
    if (lang == _language) return;
    QuestProgress.instance.markLanguageTried(lang);
    setState(() {
      _language = lang;
      _currentIndex = 0;
      _score = 0;
      _selectedIndex = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamified Exploration'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              surface.withOpacity(0.94),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(gold: gold),
            const SizedBox(height: 16),
            _QuestCard(gold: gold),
            const SizedBox(height: 16),
            _QuizCard(
              gold: gold,
              score: _score,
              currentIndex: _currentIndex,
              questionCount: _questions.length,
              question: _isFinished ? null : _currentQuestion,
              selectedIndex: _selectedIndex,
              answered: _answered,
              onSelect: _selectAnswer,
              onNext: _nextQuestion,
              onRestart: _restartQuiz,
              isFinished: _isFinished,
              selectedLanguage: _language,
              onLanguageChange: _changeLanguage,
            ),
            const SizedBox(height: 16),
            _QuestBoard(),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final Color gold;
  final int score;
  final int currentIndex;
  final int questionCount;
  final QuizQuestionData? question;
  final int? selectedIndex;
  final bool answered;
  final bool isFinished;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final QuizLanguage selectedLanguage;
  final ValueChanged<QuizLanguage> onLanguageChange;

  const _QuizCard({
    required this.gold,
    required this.score,
    required this.currentIndex,
    required this.questionCount,
    required this.question,
    required this.selectedIndex,
    required this.answered,
    required this.isFinished,
    required this.onSelect,
    required this.onNext,
    required this.onRestart,
    required this.selectedLanguage,
    required this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF87B5FF).withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF87B5FF).withOpacity(0.12),
                ),
                child: const Icon(Icons.quiz_rounded, color: Color(0xFF87B5FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heritage Quiz',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFinished
                          ? 'Final score: $score / $questionCount'
                          : 'Question ${currentIndex + 1} of $questionCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: gold.withOpacity(0.2)),
                ),
                child: Text(
                  'Score: $score',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Language selector ──────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: QuizLanguage.values.map((lang) {
                final isActive = lang == selectedLanguage;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onLanguageChange(lang),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: isActive
                            ? const Color(0xFF87B5FF).withOpacity(0.18)
                            : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF87B5FF)
                              : Colors.white.withOpacity(0.14),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(lang.flag,
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            lang.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? const Color(0xFF87B5FF)
                                  : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (isFinished)
            _QuizResultSummary(score: score, total: questionCount, gold: gold)
          else ...[
            Directionality(
              textDirection: selectedLanguage.isRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Text(
                question!.question,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(question!.options.length, (index) {
              final option = question!.options[index];
              final isSelected = selectedIndex == index;
              final isCorrect = index == question!.correctIndex;
              Color borderColor = Colors.white.withOpacity(0.12);
              Color fillColor = Colors.white.withOpacity(0.03);

              if (answered) {
                if (isCorrect) {
                  borderColor = const Color(0xFF7BD389);
                  fillColor = const Color(0xFF7BD389).withOpacity(0.12);
                } else if (isSelected) {
                  borderColor = Colors.redAccent;
                  fillColor = Colors.redAccent.withOpacity(0.12);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: answered ? null : () => onSelect(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: fillColor,
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: answered && isCorrect
                                ? const Color(0xFF7BD389)
                                : isSelected
                                    ? gold
                                    : Colors.white.withOpacity(0.08),
                          ),
                          child: Icon(
                            answered && isCorrect
                                ? Icons.check_rounded
                                : isSelected
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                            size: 16,
                            color: answered && isCorrect
                                ? Colors.black87
                                : isSelected
                                    ? Colors.black87
                                    : Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (answered) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: question!.correctIndex == selectedIndex
                      ? const Color(0xFF7BD389).withOpacity(0.12)
                      : Colors.redAccent.withOpacity(0.12),
                  border: Border.all(
                    color: question!.correctIndex == selectedIndex
                        ? const Color(0xFF7BD389).withOpacity(0.4)
                        : Colors.redAccent.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question!.correctIndex == selectedIndex
                          ? 'Correct answer. Nice work.'
                          : 'Wrong answer. Here is the correct one:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question!.options[question!.correctIndex],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question!.explanation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: Text(
                    currentIndex == questionCount - 1
                        ? 'Show Result'
                        : 'Next Question',
                  ),
                ),
              ),
            ] else
              Text(
                'Select one answer to reveal the right answer and update the score.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
          ],
          if (isFinished) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRestart,
                child: const Text('Restart Quiz'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizResultSummary extends StatelessWidget {
  final int score;
  final int total;
  final Color gold;

  const _QuizResultSummary({
    required this.score,
    required this.total,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : score / total;
    final badge = percent >= 0.9
        ? 'Heritage Master'
        : percent >= 0.7
            ? 'Heritage Explorer'
            : percent >= 0.5
                ? 'Curious Explorer'
                : 'Heritage Starter';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [gold.withOpacity(0.12), Colors.white.withOpacity(0.04)],
        ),
        border: Border.all(color: gold.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz complete',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Final score: $score / $total',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Badge unlocked: $badge',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Color gold;

  const _HeaderCard({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            gold.withOpacity(0.18),
            Theme.of(context).colorScheme.surface
          ],
        ),
        border: Border.all(color: gold.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gamified Exploration Layer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'A learning mode designed for heritage discovery through play, with rewards that keep visitors moving and learning.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Color gold;

  const _QuestCard({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold.withOpacity(0.12),
            ),
            child: Icon(Icons.route_rounded, color: gold, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Treasure hunt mission',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete clue trails, answer quiz prompts, and unlock progress badges as you explore.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Quest Board  –  shows all 4 quests with live progress
// ─────────────────────────────────────────────────────────────────────────────
class _QuestBoard extends StatelessWidget {
  const _QuestBoard();

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: QuestProgress.instance,
      builder: (context, _) {
        final q = QuestProgress.instance;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: gold.withOpacity(0.22)),
            color: gold.withOpacity(0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Quest Board',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: gold,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: gold.withOpacity(0.12),
                      border: Border.all(color: gold.withOpacity(0.25)),
                    ),
                    child: Text(
                      '${q.totalBadges} / 4 badges',
                      style: TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quest 1 – Explorer
              _QuestTile(
                icon: '🗺️',
                title: 'Explorer',
                subtitle:
                    'Open ${QuestProgress.explorerTarget} heritage location pages',
                progress: q.explorerProgress,
                progressLabel:
                    '${q.explorerCount} / ${QuestProgress.explorerTarget} visited',
                badge: '🥾 Heritage Explorer',
                accent: const Color(0xFF7BD389),
                complete: q.explorerComplete,
              ),
              const SizedBox(height: 12),

              // Quest 2 – Scholar
              _QuestTile(
                icon: '🧠',
                title: 'Scholar',
                subtitle:
                    'Score ${QuestProgress.scholarTarget} / ${q.scholarTotal} or higher on the quiz',
                progress: q.scholarProgress,
                progressLabel:
                    'Best score: ${q.scholarBest} / ${q.scholarTotal}',
                badge: '📜 Heritage Scholar',
                accent: const Color(0xFF87B5FF),
                complete: q.scholarComplete,
              ),
              const SizedBox(height: 12),

              // Quest 3 – Polyglot
              _QuestTile(
                icon: '🌍',
                title: 'Polyglot',
                subtitle:
                    'Try the quiz in ${QuestProgress.polyglotTarget} different languages',
                progress: q.polyglotProgress,
                progressLabel:
                    '${q.polyglotCount} / ${QuestProgress.polyglotTarget} languages tried',
                badge: '🌐 Polyglot Explorer',
                accent: const Color(0xFFE8A838),
                complete: q.polyglotComplete,
              ),
              const SizedBox(height: 12),

              // Quest 4 – Master (locked until the 3 above are done)
              _QuestTile(
                icon: '🏆',
                title: 'Heritage Master',
                subtitle: 'Complete all three quests above',
                progress: q.masterProgress,
                progressLabel:
                    '${q.masterDone} / 3 quests complete',
                badge: '👑 Heritage Master',
                accent: gold,
                complete: q.masterComplete,
                locked: !q.masterComplete && q.masterDone == 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final String badge;
  final Color accent;
  final bool complete;
  final bool locked;

  const _QuestTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.badge,
    required this.accent,
    required this.complete,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = locked ? Colors.white24 : accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: complete
            ? effectiveAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.03),
        border: Border.all(
          color: complete
              ? effectiveAccent.withOpacity(0.5)
              : effectiveAccent.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: locked ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (complete)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: effectiveAccent.withOpacity(0.18),
                  ),
                  child: Text(
                    '✓ Done',
                    style: TextStyle(
                      color: effectiveAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (locked)
                const Icon(Icons.lock_outline,
                    color: Colors.white24, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: locked ? Colors.white24 : Colors.white60,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: locked ? 0 : progress,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor: AlwaysStoppedAnimation<Color>(effectiveAccent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  locked ? 'Complete other quests first' : progressLabel,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: locked ? Colors.white24 : Colors.white54,
                        fontSize: 11,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Unlock: $badge',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: locked
                            ? Colors.white24
                            : effectiveAccent.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
