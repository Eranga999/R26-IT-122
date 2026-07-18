// lib/screens/model_download_screen.dart
import 'package:flutter/material.dart';
import '../services/rag_service.dart';
import 'home_screen.dart';

class ModelDownloadScreen extends StatefulWidget {
  final RagService rag;
  const ModelDownloadScreen({super.key, required this.rag});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = '';
  bool _loading = false;
  bool _done = false;
  String? _error;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  static const _gold = Color(0xFFE8B84B);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _done = false;
      _error = null;
      _status = 'Loading Phi-3 Mini into memory…';
      _progress = 0;
    });

    try {
      await widget.rag.loadLlmAfterDownload(
        onProgress: (p, s) {
          if (mounted)
            setState(() {
              _progress = p;
              _status = s;
            });
        },
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
          _status = '✓ Phi-3 Mini ready!';
          _progress = 1.0;
        });
      }
    } catch (e, stack) {
      debugPrint('Load error: $e\n$stack');
      if (mounted) {
        setState(() {
          _loading = false;
          _done = false;
          _error = _friendlyError(e.toString());
          _status = 'Failed.';
        });
      }
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('not found') || raw.contains('No such file')) {
      return '❌ Model file not found on device.\n\n'
          'Make sure Phi-3-mini-4k-instruct-q4.gguf is at:\n'
          '/storage/emulated/0/heritageAR-chatbot/models/\n\n$raw';
    }
    if (raw.contains('timeout') || raw.contains('Timeout')) {
      return '❌ Load timed out. Your device may not have enough RAM.';
    }
    return '❌ $raw';
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(rag: widget.rag)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0800),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_gold.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SlideTransition(
              position: _entrySlide,
              child: FadeTransition(
                opacity: _entryFade,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 560 : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 32 : 22,
                        24,
                        isTablet ? 32 : 22,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isTablet),
                          SizedBox(height: isTablet ? 32 : 24),
                          _buildInfoCards(),
                          const SizedBox(height: 28),
                          if (_loading || _done) _buildProgressSection(),
                          if (_error != null) _buildErrorBox(),
                          _buildActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_gold.withOpacity(0.9), const Color(0xFF8B5E00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('🤖', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'AI Model\nSetup',
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 34 : 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Load Phi-3 Mini (GGUF) — already on your device — '
          'to enable fully offline AI answers.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: isTablet ? 15 : 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.memory_rounded,
          color: _gold,
          title: 'Phi-3-mini-4k-instruct-q4.gguf · ~2.3 GB',
          subtitle:
              'Already downloaded to your models folder. No internet needed.',
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.wifi_off_rounded,
          color: Colors.greenAccent,
          title: 'Fully Offline',
          subtitle: 'No network required. Model runs entirely on device.',
        ),
        const SizedBox(height: 10),
       
      ],
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _done ? Icons.check_circle_rounded : Icons.memory_rounded,
                color: _done ? Colors.greenAccent : _gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _done ? Colors.greenAccent : _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: LinearProgressIndicator(
                value: (_loading && _progress == 0) ? null : _progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(
                  _done ? Colors.greenAccent : _gold,
                ),
              ),
            ),
          ),
          if (_progress > 0 && _progress < 1.0) ...[
            const SizedBox(height: 6),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: _gold.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_done) {
      return _PrimaryButton(
        icon: Icons.rocket_launch_rounded,
        label: 'Launch App',
        onPressed: _goToApp,
      );
    }

    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading model into memory…\nDo not close the app.',
                    style: TextStyle(color: _gold, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryButton(
          icon: Icons.memory_rounded,
          label: _error != null
              ? 'Retry Load Model'
              : 'Load Phi-3 Mini into Memory',
          onPressed: _loadModel,
        ),
      ],
    );
  }
} 

// ── Info Card ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color == Colors.white38 ? Colors.white54 : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.5,
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

// ── Buttons ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B84B),
          foregroundColor: const Color(0xFF1A0E00),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: const BorderSide(color: Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
