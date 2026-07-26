import 'package:flutter/material.dart';

class GamifiedExploreScreen extends StatefulWidget {
  const GamifiedExploreScreen({super.key});

  @override
  State<GamifiedExploreScreen> createState() => _GamifiedExploreScreenState();
}

class _GamifiedExploreScreenState extends State<GamifiedExploreScreen> {
  final List<_QuizQuestion> _questions = const [
    _QuizQuestion(
      question: 'Which site is a UNESCO World Heritage Site in Sri Lanka?',
      options: [
        'Sigiriya Rock Fortress',
        'Bentota Beach',
        'Nuwara Eliya Town',
        'Kandy Railway Station',
      ],
      correctIndex: 0,
      explanation:
          'Sigiriya Rock Fortress was inscribed as a UNESCO World Heritage Site in 1982.',
    ),
    _QuizQuestion(
      question: 'What animal is symbolically linked to the Lion Gate?',
      options: [
        'Elephant',
        'Lion',
        'Peacock',
        'Dragon',
      ],
      correctIndex: 1,
      explanation:
          'The entrance is known as Lion Gate because it once featured a colossal lion form.',
    ),
    _QuizQuestion(
      question: 'What is the Mirror Wall famous for?',
      options: [
        'Ancient poetic graffiti',
        'Hidden treasure maps',
        'Modern murals',
        'Water storage',
      ],
      correctIndex: 0,
      explanation:
          'Visitors wrote poems and inscriptions on the wall from the 6th century onward.',
    ),
    _QuizQuestion(
      question: 'Which part of Sigiriya shows advanced hydraulic engineering?',
      options: [
        'Water Gardens',
        'Summit Palace',
        'Gallery entrance',
        'Lion paws',
      ],
      correctIndex: 0,
      explanation:
          'The Water Gardens contain ponds, channels, and fountain systems powered by ancient hydraulics.',
    ),
    _QuizQuestion(
      question: 'Who built Sigiriya Rock Fortress as a royal capital?',
      options: [
        'King Dutugemunu',
        'King Kashyapa I',
        'King Parakramabahu',
        'King Valagamba',
      ],
      correctIndex: 1,
      explanation:
          'King Kashyapa I built the site during his reign between 477 and 495 AD.',
    ),
    _QuizQuestion(
      question: 'What do the Sigiriya frescoes mainly depict?',
      options: [
        'Warriors on horseback',
        'Celestial maidens',
        'Market scenes',
        'Royal elephants only',
      ],
      correctIndex: 1,
      explanation:
          'The frescoes depict Sigiriya Maidens, often described as celestial female figures.',
    ),
    _QuizQuestion(
      question:
          'Approximately how high does the Sigiriya rock rise above the plains?',
      options: [
        '50 metres',
        '100 metres',
        '200 metres',
        '500 metres',
      ],
      correctIndex: 2,
      explanation:
          'The rock rises about 200 metres above the surrounding plains.',
    ),
    _QuizQuestion(
      question:
          'What was the original purpose of the site before it became a royal citadel?',
      options: [
        'Fishing port',
        'Buddhist monastery',
        'Tea estate',
        'Military airport',
      ],
      correctIndex: 1,
      explanation:
          'The site had earlier served as a Buddhist monastery before being transformed by King Kashyapa.',
    ),
    _QuizQuestion(
      question: 'What is the best description of the treasure hunt mechanic?',
      options: [
        'One fixed route with no progress',
        'Clue-based discovery with rewards',
        'Only reading long paragraphs',
        'Random guessing game',
      ],
      correctIndex: 1,
      explanation:
          'The gamified layer is designed around clue trails, discovery, and achievements.',
    ),
    _QuizQuestion(
      question: 'How many questions are included in this quiz set?',
      options: [
        '5',
        '7',
        '10',
        '12',
      ],
      correctIndex: 2,
      explanation: 'This quiz set contains 10 multiple-choice questions.',
    ),
  ];

  int _currentIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;

  _QuizQuestion get _currentQuestion => _questions[_currentIndex];

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
            ),
            const SizedBox(height: 16),
            _FeatureCard(
              icon: Icons.explore_rounded,
              title: 'AR Treasure Hunts',
              subtitle:
                  'Guide the visitor from clue to clue and turn the site into a discovery game.',
              accent: const Color(0xFF7BD389),
              bullets: const [
                'Clue cards for landmarks',
                'GPS-based progress',
                'Reward moments at each stop',
              ],
            ),
            const SizedBox(height: 14),
            _FeatureCard(
              icon: Icons.emoji_events_rounded,
              title: 'Achievement Badges',
              subtitle:
                  'Unlock badges for exploration streaks, quiz scores, and completed routes.',
              accent: gold,
              bullets: const [
                'Heritage Explorer badge',
                'Location mastery badges',
                'Progress milestones',
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: gold.withOpacity(0.22)),
                color: gold.withOpacity(0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example quest',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: gold,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Find 5 landmarks.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock: 🏆 Heritage Explorer',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(gold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3 of 5 landmarks found',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
              ),
            ),
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
  final _QuizQuestion? question;
  final int? selectedIndex;
  final bool answered;
  final bool isFinished;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;
  final VoidCallback onRestart;

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
          const SizedBox(height: 16),
          if (isFinished)
            _QuizResultSummary(score: score, total: questionCount, gold: gold)
          else ...[
            Text(
              question!.question,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final List<String> bullets;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: accent.withOpacity(0.22)),
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
                  color: accent.withOpacity(0.12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
