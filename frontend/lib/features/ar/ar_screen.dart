import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ar_availability.dart';
import '../../features/database/landmark_model.dart';
import 'ar_camera_view.dart';
import 'street_view_screen.dart';
import 'ar_navigation_screen.dart';

/// AR overlay screen – dynamically checks ARCore availability on the device.
/// Shows a supported or unsupported UI accordingly.
class ArScreen extends StatefulWidget {
  final LandmarkModel landmark;

  const ArScreen({super.key, required this.landmark});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  static const _gradients = [
    [Color(0xFFB71C1C), Color(0xFFE53935)],
    [Color(0xFFE65100), Color(0xFFFF8F00)],
    [Color(0xFF1A237E), Color(0xFF3949AB)],
  ];

  static const _icons = [
    Icons.castle_rounded,
    Icons.temple_hindu_rounded,
    Icons.account_balance_rounded,
  ];

  ArStatus? _arStatus;
  bool _checking = true;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _checkAr();
  }

  Future<void> _checkAr() async {
    final status = await ArAvailability.check();
    if (mounted) {
      setState(() {
        _arStatus = status;
        _checking = false;
      });
    }
  }

  Future<void> _installArCore() async {
    if (_installing) return;
    setState(() => _installing = true);
    // requestInstall() triggers the Google Play in-app overlay for ARCore.
    await ArAvailability.requestInstall();
    // Re-check status once the user returns from the Play Store flow.
    final status = await ArAvailability.check();
    if (mounted) {
      setState(() {
        _arStatus = status;
        _installing = false;
      });
    }
  }

  void _onLaunchAr(List<Color> colors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArNavigationScreen(
          destination: widget.landmark.name,
          detectedLabel: _labelFromName(widget.landmark.name),
        ),
      ),
    );
  }

  String _labelFromName(String name) {
    const map = {
      'Sigiriya': 'sigiriya_lion_paws',
      'Dambulla Cave Temple': 'sigiriya_mirror_wall',
      'Polonnaruwa': 'sigiriya_lion_rock',
    };
    return map[name] ?? 'sigiriya_lion_paws';
  }

  @override
  Widget build(BuildContext context) {
    final lm = widget.landmark;
    final idx = ((lm.id ?? 1) - 1) % _gradients.length;
    final colors = _gradients[idx];
    final icon = _icons[idx];

    final arSupported = _arStatus?.supported ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D0000),
                  colors[0].withValues(alpha: 0.3),
                  const Color(0xFF050505),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App bar row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            lm.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // AR status badge
                        if (!_checking)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: arSupported
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : Colors.red.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: arSupported
                                      ? Colors.green.shade400
                                      : Colors.red.shade400),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                arSupported
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: arSupported
                                    ? Colors.green.shade300
                                    : Colors.red.shade300,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                arSupported ? 'AR Ready' : 'AR N/A',
                                style: TextStyle(
                                    color: arSupported
                                        ? Colors.green.shade300
                                        : Colors.red.shade300,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                        if (_checking)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white54)),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Landmark icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 56),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    lm.name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.secondary.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'AR Experience',
                      style: TextStyle(
                          color: Color(0xFFFFB300),
                          fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Status message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _checking
                            ? Colors.white10
                            : arSupported
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _checking
                              ? Colors.white24
                              : arSupported
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: _checking
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white54)),
                                SizedBox(width: 10),
                                Text('Checking AR support…',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 13)),
                              ],
                            )
                          : arSupported
                              ? const Column(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.green, size: 32),
                                  SizedBox(height: 10),
                                  Text(
                                    'Your device supports AR!',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Tap "Launch AR" to start the immersive 3-D overlay experience for this landmark.',
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ])
                              : Column(children: [
                                  Icon(
                                    (_arStatus?.isEmulator ?? false)
                                        ? Icons.computer_rounded
                                        : Icons.warning_amber_rounded,
                                    color: (_arStatus?.isEmulator ?? false)
                                        ? Colors.blueGrey.shade300
                                        : Colors.orange,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    (_arStatus?.isEmulator ?? false)
                                        ? 'Emulator Detected – ARCore Not Installed'
                                        : 'AR Not Available on This Device',
                                    style: TextStyle(
                                        color: (_arStatus?.isEmulator ?? false)
                                            ? Colors.blueGrey.shade300
                                            : Colors.orange,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _arStatus?.reason ??
                                        'AR is not supported on this device.',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                  // Show Install ARCore button when device/emulator
                                  // supports it but ARCore isn't installed yet.
                                  if (_arStatus?.canInstall == true ||
                                      (_arStatus?.isEmulator ?? false)) ...[
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _installing ? null : _installArCore,
                                        icon: _installing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(Icons.download_rounded,
                                                size: 18),
                                        label: Text(_installing
                                            ? 'Opening Google Play…'
                                            : 'Install ARCore from Google Play'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1565C0),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '💡 After installing, return to this screen.',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ]),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _checking
                                ? null
                                : () => _onLaunchAr(colors),
                            icon: (_arStatus?.canInstall == true)
                                ? const Icon(Icons.download_rounded)
                                : const Icon(Icons.view_in_ar_rounded),
                            label: const Text('Start Route Tour'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _checking
                                  ? Colors.grey.shade700
                                  : arSupported
                                      ? colors[0]
                                      : (_arStatus?.canInstall == true)
                                          ? const Color(0xFF1565C0)
                                          : Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Go Back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
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