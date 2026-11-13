import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.easeOut,
  );
  late final AnimationController _textCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _textCtrl,
    curve: Curves.easeOut,
  );
  late final AnimationController _dotsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _runSequence();
  }

  Future<void> _runSequence() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      await _logoCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      await _textCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1400));
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF050f0a),
      body: Stack(
        children: [
          Positioned(
            left: size.width / 2 - 180,
            top: size.height * 0.30,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0e7a50).withOpacity(0.28),
                    const Color(0xFF0a6e82).withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: const BrikolIcon(size: 160),
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      const Text(
                        'brikol.ma',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFc9a44a),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'خدمة نقية... فبلاصتك',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Color(0xFFc9a44a),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _dotsCtrl,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = i / 3;
                    final t = (_dotsCtrl.value - phase) % 1.0;
                    final opacity =
                        (sin(t * pi * 2) * 0.5 + 0.5).clamp(0.15, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BrikolIcon extends StatelessWidget {
  const BrikolIcon({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0e8050).withOpacity(0.35),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          'icons/Icon-192.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0e8050), Color(0xFF0a6e8a)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}