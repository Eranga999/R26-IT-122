// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../models/location_model.dart';
import '../services/rag_service.dart';
import '../data/sigiriya_knowledge_base.dart';
import '../widgets/location_selector.dart';
import 'model_download_screen.dart';

// ═══════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final RagService rag;
  const ChatScreen({super.key, required this.rag});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) => _SelectionPage(rag: widget.rag);
}

// ═══════════════════════════════════════════════════════
//  PAGE 1 — Selection
// ═══════════════════════════════════════════════════════
class _SelectionPage extends StatefulWidget {
  final RagService rag;
  const _SelectionPage({required this.rag});

  @override
  State<_SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<_SelectionPage>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFE8B84B);
  static const _bg = Color(0xFF0D0800);
  static const _surface = Color(0xFF160D00);
  static const _border = Color(0xFF2C1A00);

  final _textController = TextEditingController();
  String? _selectedLocation;
  String _mode = 'brief';

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _textController.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── cache helpers ─────────────────────────────────────
  Future<void> _clearCache() async {
    await widget.rag.clearCache();
    if (mounted) _snack('✓ Cache cleared.');
  }

  Future<void> _showCacheStats() async {
    final size = await widget.rag.cacheSize;
    if (mounted) _snack('Cache: $size entr${size == 1 ? 'y' : 'ies'} stored.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goExplore() {
    final loc = _selectedLocation ?? _textController.text.trim();
    if (loc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a location first.'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: _ResultsPage(rag: widget.rag, location: loc, mode: _mode),
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 540 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(),
                    const SizedBox(height: 40),
                    _label('SELECT LOCATION'),
                    const SizedBox(height: 10),
                    _locationCard(),
                    const SizedBox(height: 28),
                    _label('INFORMATION DEPTH'),
                    const SizedBox(height: 10),
                    _modeRow(),
                    const SizedBox(height: 40),
                    _exploreBtn(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: const Color(0xFF100900),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            _logoCircle(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Sigiriya Heritage',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.rag.llmReady)
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: Colors.orangeAccent),
              tooltip: 'Download Phi-3 Mini LLM',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ModelDownloadScreen(rag: widget.rag),
                ),
              ),
            ),
          _PipelineDots(status: widget.rag.status),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: _gold.withOpacity(0.75),
              size: 20,
            ),
            color: const Color(0xFF1E1200),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'cache_stats') _showCacheStats();
              if (val == 'clear_cache') _clearCache();
            },
            itemBuilder: (_) => [
              _popupItem(
                  'cache_stats', Icons.analytics_outlined, 'Cache Stats'),
              _popupItem(
                'clear_cache',
                Icons.cleaning_services_outlined,
                'Clear Cache',
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      );

  PopupMenuItem<String> _popupItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, color: _gold, size: 17),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _logoCircle() => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFE8B84B), Color(0xFF8B5E00)],
            center: Alignment(-0.2, -0.2),
          ),
        ),
        child: const Center(child: Text('🏔️', style: TextStyle(fontSize: 17))),
      );

  Widget _heroHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Explore\nSigiriya',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a heritage site and discover its story — from a quick overview to an in-depth historical account.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      );

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: _gold.withOpacity(0.55),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.9,
        ),
      );

  Widget _locationCard() => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(4),
        child: LocationSelector(
          controller: _textController,
          selectedLocation: _selectedLocation,
          onSelected: (loc) => setState(() => _selectedLocation = loc),
        ),
      );

  Widget _modeRow() => Row(
        children: [
          Expanded(
            child: _ModeCard(
              label: 'Brief',
              icon: Icons.bolt_rounded,
              description: 'Quick highlights & key facts',
              selected: _mode == 'brief',
              onTap: () => setState(() => _mode = 'brief'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ModeCard(
              label: 'Detailed',
              icon: Icons.menu_book_rounded,
              description: 'Full history & deep context',
              selected: _mode == 'detailed',
              onTap: () => setState(() => _mode = 'detailed'),
            ),
          ),
        ],
      );

  Widget _exploreBtn() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _goExplore,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: const Color(0xFF1A0E00),
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Explore This Location',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════
//  Mode card
// ═══════════════════════════════════════════════════════
class _ModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  static const _gold = Color(0xFFE8B84B);
  static const _surface = Color(0xFF160D00);
  static const _border = Color(0xFF2C1A00);

  const _ModeCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _gold.withOpacity(0.08) : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold.withOpacity(0.55) : _border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? _gold : Colors.white.withOpacity(0.32),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _gold : Colors.white.withOpacity(0.50),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.32),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  PAGE 2 — Results  (full text first, photos below)
// ═══════════════════════════════════════════════════════
class _ResultsPage extends StatefulWidget {
  final RagService rag;
  final String location;
  final String mode;

  const _ResultsPage({
    required this.rag,
    required this.location,
    required this.mode,
  });

  @override
  State<_ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<_ResultsPage> {
  static const _gold = Color(0xFFE8B84B);
  static const _bg = Color(0xFF0D0800);
  static const _surface = Color(0xFF160D00);
  static const _border = Color(0xFF2C1A00);

  String _result = '';
  bool _loading = true;
  bool _streaming = false;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _result = '';
      _error = null;
      _streaming = false;
    });
    try {
      final answer = await widget.rag.ask(
        widget.location,
        widget.mode,
        onToken: (token) {
          if (!mounted) return;
          setState(() {
            _result += token;
            _loading = false;
            _streaming = true;
          });
          _scrollToBottom();
        },
      );
      if (mounted)
        setState(() {
          _result = answer;
          _loading = false;
          _streaming = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
          _streaming = false;
        });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> get _images {
    final name = widget.location.toLowerCase();
    final loc = kSigiriyaLocations.firstWhere(
      (l) => l.name.toLowerCase() == name,
      orElse: () => kSigiriyaLocations.firstWhere(
        (l) =>
            l.name.toLowerCase().contains(name) ||
            name.contains(l.name.toLowerCase()),
        orElse: () => kSigiriyaLocations.first,
      ),
    );
    return loc.imageAssets;
  }

  // ── build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _bg,

      // ── App bar: back + title + status ─────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF100900),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Back button — only way to leave this page
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white70,
              size: 15,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.location,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              widget.mode == 'brief' ? 'Brief overview' : 'Detailed account',
              style: TextStyle(
                color: _gold.withOpacity(0.60),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_streaming)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _gold,
                  ),
                ),
              ),
            ),
          if (!_loading && !_streaming)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: _gold.withOpacity(0.65),
                size: 19,
              ),
              onPressed: _fetch,
            ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Scrollable body ─────────────────────────────────
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 700 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ① Status / mode row
                _metaRow(),

                // ② ─────── FULL TEXT (prominent, no chrome) ──────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                  child: _loading
                      ? _shimmerBlock()
                      : _error != null
                          ? _errorCard()
                          : _ResultText(text: _result),
                ),

                // ③ ─────── PHOTOS SECTION (below all text) ───────
                if (!_loading && _error == null) ...[
                  const SizedBox(height: 44),
                  _photoDivider(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _PhotoGrid(
                      images: _images,
                      locationName: widget.location,
                    ),
                  ),
                ],

                SizedBox(height: 48 + bottomPad),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────

  Widget _metaRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Row(
        children: [
          // Mode pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withOpacity(0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.mode == 'brief'
                      ? Icons.bolt_rounded
                      : Icons.menu_book_rounded,
                  size: 12,
                  color: _gold,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.mode == 'brief' ? 'Brief' : 'Detailed',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Live status
          if (_loading)
            Text(
              'Preparing…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.30),
                fontSize: 12,
              ),
            )
          else if (_streaming)
            _PulsingLabel(text: 'Generating…')
          else if (_error == null)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 13,
                  color: Colors.greenAccent.withOpacity(0.60),
                ),
                const SizedBox(width: 5),
                Text(
                  'Complete',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _shimmerBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Shimmer(width: 220, height: 24),
          const SizedBox(height: 22),
          ...List.generate(
            7,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _Shimmer(width: i == 6 ? 150 : double.infinity, height: 14),
            ),
          ),
          const SizedBox(height: 22),
          _Shimmer(width: 160, height: 18),
          const SizedBox(height: 14),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _Shimmer(width: i == 3 ? 190 : double.infinity, height: 14),
            ),
          ),
        ],
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.38), fontSize: 12),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetch,
              child: const Text(
                'Tap to retry',
                style: TextStyle(
                  color: _gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _photoDivider() {
    final imgs = _images;
    if (imgs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'PHOTOS',
            style: TextStyle(
              color: _gold.withOpacity(0.60),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.9,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· ${widget.location}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.26),
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Text(
            '${imgs.length} photo${imgs.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Markdown-lite result text
// ═══════════════════════════════════════════════════════
class _ResultText extends StatelessWidget {
  final String text;
  const _ResultText({required this.text});

  static const _gold = Color(0xFFE8B84B);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: text.split('\n').map((line) {
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Text(
              line.replaceFirst('# ', ''),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.6,
              ),
            ),
          );
        }
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              line.replaceFirst('## ', ''),
              style: const TextStyle(
                color: _gold,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          );
        }
        if (line.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 5),
            child: Text(
              line.replaceFirst('### ', ''),
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        if (line.startsWith('- ') || line.startsWith('• ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineBold(line.replaceFirst(RegExp(r'^[-•]\s'), '')),
                ),
              ],
            ),
          );
        }
        if (line.trim().isEmpty) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InlineBold(line),
        );
      }).toList(),
    );
  }
}

class _InlineBold extends StatelessWidget {
  final String text;
  const _InlineBold(this.text);

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final rx = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in rx.allMatches(text)) {
      if (m.start > last) {
        spans.add(
          TextSpan(
            text: text.substring(last, m.start),
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 15.5,
              height: 1.72,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
            height: 1.72,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: TextStyle(
            color: Colors.white.withOpacity(0.68),
            fontSize: 15.5,
            height: 1.72,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ═══════════════════════════════════════════════════════
//  2-column photo grid
// ═══════════════════════════════════════════════════════
class _PhotoGrid extends StatelessWidget {
  final List<String> images;
  final String locationName;

  const _PhotoGrid({required this.images, required this.locationName});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) => _GridThumb(
        assetPath: images[i],
        allImages: images,
        index: i,
        locationName: locationName,
      ),
    );
  }
}

class _GridThumb extends StatefulWidget {
  final String assetPath;
  final List<String> allImages;
  final int index;
  final String locationName;

  const _GridThumb({
    required this.assetPath,
    required this.allImages,
    required this.index,
    required this.locationName,
  });

  @override
  State<_GridThumb> createState() => _GridThumbState();
}

class _GridThumbState extends State<_GridThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  static const _gold = Color(0xFFE8B84B);

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _open() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _Gallery(
            images: widget.allImages,
            initialIndex: widget.index,
            locationName: widget.locationName,
          ),
          fullscreenDialog: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          _open();
        },
        onTapCancel: () => _press.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                widget.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1000),
                  child: Icon(
                    Icons.landscape_rounded,
                    color: _gold.withOpacity(0.22),
                    size: 32,
                  ),
                ),
              ),
              // bottom gradient
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              // expand icon
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Full-screen gallery
// ═══════════════════════════════════════════════════════
class _Gallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String locationName;

  const _Gallery({
    required this.images,
    required this.initialIndex,
    required this.locationName,
  });

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _ctrl;
  late int _idx;

  static const _gold = Color(0xFFE8B84B);

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.locationName,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_idx + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.asset(
                    widget.images[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: _gold.withOpacity(0.28),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Image not available',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 28 + MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    final active = i == _idx;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: active ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? _gold : Colors.white30,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            if (widget.images.length > 1 && _idx > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _Arrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _ctrl.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
            if (widget.images.length > 1 && _idx < widget.images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _Arrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _ctrl.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
      );
}

// ═══════════════════════════════════════════════════════
//  Shimmer loading bar
// ═══════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF1E1200),
              Color.lerp(
                const Color(0xFF1E1200),
                const Color(0xFF3B2400),
                _ctrl.value,
              )!,
              const Color(0xFF1E1200),
            ],
            stops: [0.0, _ctrl.value.clamp(0.01, 0.99), 1.0],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Pulsing "Generating…" label
// ═══════════════════════════════════════════════════════
class _PulsingLabel extends StatefulWidget {
  final String text;
  const _PulsingLabel({required this.text});

  @override
  State<_PulsingLabel> createState() => _PulsingLabelState();
}

class _PulsingLabelState extends State<_PulsingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                const Color(0xFFE8B84B).withOpacity(0.22),
                const Color(0xFFE8B84B),
                _anim.value,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            widget.text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.28),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Pipeline status dots
// ═══════════════════════════════════════════════════════
class _PipelineDots extends StatelessWidget {
  final RagInitStatus status;
  const _PipelineDots({required this.status});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _D('E', status.embeddingReady),
          const SizedBox(width: 3),
          _D('V', status.vectorStoreReady),
          const SizedBox(width: 3),
          _D('L', status.llmReady),
          const SizedBox(width: 3),
          _D('C', status.cacheReady),
        ],
      );
}

class _D extends StatelessWidget {
  final String label;
  final bool ready;
  const _D(this.label, this.ready);

  static const _gold = Color(0xFFE8B84B);

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ready
              ? _gold.withOpacity(0.10)
              : Colors.orangeAccent.withOpacity(0.07),
          border: Border.all(
            color: ready
                ? _gold.withOpacity(0.65)
                : Colors.orangeAccent.withOpacity(0.35),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: ready ? _gold : Colors.orangeAccent,
            ),
          ),
        ),
      );
}
