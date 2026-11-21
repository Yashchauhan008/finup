import 'package:flutter/material.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'legal_screen.dart';
import 'update_screen.dart';

const kPortfolio = 'https://yashchauhan.pro';

class AboutScreenV2 extends StatefulWidget {
  const AboutScreenV2({super.key});

  @override
  State<AboutScreenV2> createState() => _AboutScreenV2State();
}

class _AboutScreenV2State extends State<AboutScreenV2> {
  String _ver = '';

  @override
  void initState() {
    super.initState();
    Native.appInfo().then((v) {
      if (mounted) setState(() => _ver = v.$2 > 0 ? '${v.$1} (build ${v.$2})' : v.$1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    void open(Widget p) => Navigator.of(context).push(fadeRoute(p));
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Center(child: FinUpLogo(size: 96)),
          const SizedBox(height: 16),
          Center(child: Text('FinUp', style: AppText.display(size: 30, color: fin.text))),
          if (_ver.isNotEmpty)
            Center(child: Text('Version $_ver', style: TextStyle(color: fin.subtext))),
          const SizedBox(height: 10),
          Center(
            child: Text('Your money, auto-tracked. Private. Offline. Yours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: fin.subtext, height: 1.5)),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.cardGradients[0],
              borderRadius: BorderRadius.circular(26),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: OrbitPainter(0.2,
                        line: Colors.white.withValues(alpha: 0.18),
                        showDots: false,
                        center: const Alignment(0.8, -0.2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Made by Yash with ❤️',
                          style: AppText.display(size: 20, color: Colors.white)),
                      const SizedBox(height: 6),
                      const Text('Designed and developed FinUp',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Native.openUrl(kPortfolio),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.language_rounded, color: AppColors.ink, size: 20),
                              SizedBox(width: 8),
                              Text('yashchauhan.pro',
                                  style: TextStyle(
                                      color: AppColors.ink, fontWeight: FontWeight.w700)),
                              SizedBox(width: 6),
                              Icon(Icons.open_in_new_rounded, color: AppColors.ink, size: 16),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: fin.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('Check for updates'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const UpdateScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share FinUp'),
                onTap: () => AppLockGate.suspendWhile(
                    () => Native.shareText(UpdateService.shareText)),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Terms & Conditions'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const LegalScreen(
                    title: 'Terms & Conditions',
                    updated: '13 October 2026',
                    sections: termsSections)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const LegalScreen(
                    title: 'Privacy Policy',
                    updated: '13 October 2026',
                    sections: privacySections)),
              ),
              const ListTile(
                leading: Icon(Icons.code_rounded),
                title: Text('Built with Flutter'),
                subtitle: Text('No cloud, no tracking, no ads'),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('© 2026 Yash Chauhan',
                style: TextStyle(color: fin.subtext, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
