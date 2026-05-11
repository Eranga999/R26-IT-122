// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../services/rag_service.dart';
import 'home_screen.dart';
import 'model_download_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  final _rag = RagService();
  double _progress = 0;
  String _stepText = 'Initialising…';

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeIn);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _logoCtrl.forward().then((_) => _contentCtrl.forward());
    _initRag();
  }

  Future<void> _initRag() async {
    await Future.delayed(const Duration(milliseconds: 900));

    await _rag.init(
      onProgress: (step, progress) {
        if (mounted)
          setState(() {
            _stepText = step;
            _progress = progress;
          });
      },
    );

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (!_rag.llmReady) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ModelDownloadScreen(rag: _rag),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeScreen(rag: _rag),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0800),
      body: Stack(
        children: [
          // Background gradient mesh
          Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),

          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 480 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: _buildLogo(isTablet),
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),

                    // Title & subtitle
                    SlideTransition(
                      position: _contentSlide,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: _buildTitleSection(isTablet),
                      ),
                    ),

                    SizedBox(height: isTablet ? 60 : 48),

                    // Progress
                    FadeTransition(
                      opacity: _contentFade,
                      child: _buildProgress(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isTablet) {
    final logoSize = isTablet ? 130.0 : 110.0;
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFE8B84B), Color(0xFF8B5E00)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A017).withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: const Color(0xFFD4A017).withOpacity(0.15),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Text('🏔️', style: TextStyle(fontSize: isTablet ? 62 : 52)),
      ),
    );
  }

  Widget _buildTitleSection(bool isTablet) {
    return Column(
      children: [
        Text(
          'SIGIRIYA',
          style: TextStyle(
            color: const Color(0xFFE8B84B),
            fontSize: isTablet ? 36 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Heritage Guide',
          style: TextStyle(
            color: Colors.white38,
            fontSize: isTablet ? 16 : 13,
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 16),
        
      ],
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 3,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFE8B84B)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _stepText,
          style: const TextStyle(
            color: Color(0xFFE8B84B),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Soft radial glow top-center
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFFD4A017).withOpacity(0.06),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width / 2, size.height * 0.3),
            radius: size.width * 0.7,
          ),
        );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.3),
      size.width * 0.7,
      paint,
    );

    // Bottom glow
    paint.shader =
        RadialGradient(
          colors: [
            const Color(0xFF4A2800).withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.2, size.height * 0.85),
            radius: size.width * 0.5,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.85),
      size.width * 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
