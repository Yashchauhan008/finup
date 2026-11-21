import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    Future.delayed(const Duration(milliseconds: 2200), _go);
  }

  void _go() {
    if (!mounted) return;
    final onboarded = context.read<SettingsState>().onboarded;
    Navigator.of(context).pushReplacement(
        fadeRoute(onboarded ? const HomeShell() : const IntroScreen()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          const Positioned.fill(child: OrbitBackground()),
          Positioned(
            left: 28,
            right: 28,
            bottom: 90,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = Curves.easeOutCubic.transform(_c.value);
                final pop = Curves.easeOutBack
                    .transform((_c.value * 1.4).clamp(0.0, 1.0).toDouble());
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - v)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                            scale: pop,
                            alignment: Alignment.bottomLeft,
                            child: const FinUpLogo(size: 76)),
                        const SizedBox(height: 18),
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                                  colors: [AppColors.lavender, AppColors.pink])
                              .createShader(r),
                          child: Text('FinUp',
                              style:
                                  AppText.display(size: 56, color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your money, auto-tracked.\nPrivate. Offline. Yours.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 17, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
