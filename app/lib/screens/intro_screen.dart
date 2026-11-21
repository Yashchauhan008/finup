import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    _IntroData(
      'Every rupee,\nauto-tracked',
      'FinUp reads your bank SMS right on your phone and turns them into clean entries with amount, time, account and balance.',
    ),
    _IntroData(
      'Review in\n30 seconds',
      'Open FinUp at night, tap a category for each new transaction and you are done. It learns your merchants as you go.',
    ),
    _IntroData(
      'Know who\nowes you',
      'Keep a running ledger for friends and family. UPI transfers link to the right person automatically.',
    ),
  ];

  void _finish() =>
      Navigator.of(context).pushReplacement(fadeRoute(const SetupScreen()));

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _pc.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _art(int i) => switch (i) {
        0 => const SmsArt(),
        1 => const ReviewArt(),
        _ => const LedgerArt(),
      };

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: OrbitBackground(
                    center: Alignment(0.2, -0.6), scale: 1.1),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: last ? 0 : 1,
                        child: TextButton(
                          onPressed: last ? null : _finish,
                          child: const Text('Skip',
                              style: TextStyle(color: Colors.white60)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) {
                        final d = _pages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _art(i),
                                  ),
                                ),
                              ),
                              Text(d.title,
                                  style: AppText.display(
                                      size: 32, color: Colors.white)),
                              const SizedBox(height: 14),
                              Text(
                                d.body,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: Row(
                      children: [
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _page ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? AppColors.lavender
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _next,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            height: 60,
                            width: last ? 170 : 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.lavender, AppColors.pink],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: last
                                  ? const Text(
                                      'Get started',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded,
                                      color: AppColors.ink),
                            ),
                          ),
                        ),
                      ],
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

class _IntroData {
  final String title;
  final String body;
  const _IntroData(this.title, this.body);
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.lavender.withValues(alpha: 0.35),
            AppColors.lavender.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class SmsArt extends StatelessWidget {
  const SmsArt({super.key});

  static const _rows = [
    ('Rs.4,000.00 Dr.', 'to cafe@okaxis', '06:42 AM'),
    ('Rs.126.00 Dr.', 'to store@ybl', '05:32 AM'),
    ('Rs.12,500.00 Cr.', 'Salary credited', '09:00 AM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 4200),
      builder: (context, t) {
        final out = 1 - iv(t, 0.88, 1.0);
        return SizedBox(
          width: 290,
          height: 290,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _Glow(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _rows.length; i++) _bubble(i, t, out),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(int i, double t, double out) {
    final s = 0.08 + i * 0.18;
    final v = iv(t, s, s + 0.22);
    final e = Curves.easeOutCubic.transform(v);
    final tick = iv(t, s + 0.25, s + 0.35);
    final r = _rows[i];
    final credit = r.$1.contains('Cr.');
    return Opacity(
      opacity: (v * out).clamp(0.0, 1.0).toDouble(),
      child: Transform.translate(
        offset: Offset(-36 * (1 - e), 0),
        child: Container(
          width: 270,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B25),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppColors.lavender.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.lavender, AppColors.pink]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sms_rounded,
                    color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.$1,
                      style: TextStyle(
                        color: credit ? AppColors.income : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(r.$2,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(r.$3,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scale: tick,
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.income, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewArt extends StatelessWidget {
  const ReviewArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 3800),
      builder: (context, t) {
        final fade = iv(t, 0.0, 0.08) * (1 - iv(t, 0.9, 1.0));
        final pick = iv(t, 0.3, 0.4);
        final done = iv(t, 0.48, 0.62);
        final picked = pick > 0.5;
        final finished = done > 0.5;
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: 290,
            height: 290,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _Glow(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 270,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.white12,
                                  const Color(0xFFF4A261), done),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              finished
                                  ? Icons.restaurant_rounded
                                  : Icons.help_outline_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Swiggy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  finished ? 'Food & Dining' : 'Needs a category',
                                  style: TextStyle(
                                    color: finished
                                        ? const Color(0xFFF4A261)
                                        : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text('₹249',
                              style: AppText.display(
                                  size: 17, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _chip('Food', picked),
                        const SizedBox(width: 8),
                        _chip('Shopping', false),
                        const SizedBox(width: 8),
                        _chip('Travel', false),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Transform.scale(
                      scale: Curves.easeOutBack.transform(done),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.income,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [AppColors.lavender, AppColors.pink])
            : null,
        color: selected ? null : const Color(0xFF1B1B25),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: selected ? Colors.transparent : Colors.white12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.ink : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LedgerArt extends StatelessWidget {
  const LedgerArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 3400),
      builder: (context, t) {
        final fade = iv(t, 0.0, 0.08) * (1 - iv(t, 0.9, 1.0));
        final move = Curves.easeInOutCubic.transform(iv(t, 0.12, 0.55));
        final pill = iv(t, 0.58, 0.72);
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: 290,
            height: 290,
            child: Stack(
              children: [
                const Positioned.fill(child: Center(child: _Glow())),
                Positioned(
                  left: 70,
                  right: 70,
                  top: 119,
                  child: Container(height: 2, color: Colors.white12),
                ),
                Positioned(
                    left: 14, top: 82, child: _avatar('You', AppColors.lavender)),
                Positioned(
                    right: 14, top: 82, child: _avatar('R', AppColors.pink)),
                Positioned(
                  left: 90 + move * 70,
                  top: 100,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xFFF6D365), Color(0xFFFDA085)]),
                    ),
                    child: const Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 190,
                  child: Center(
                    child: Opacity(
                      opacity: pill,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - pill)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B25),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: AppColors.income.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.north_east_rounded,
                                  color: AppColors.income, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Rahul owes you ₹500',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String label, Color c) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.18),
        border: Border.all(color: c, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w800,
            fontSize: label.length > 1 ? 16 : 26,
          ),
        ),
      ),
    );
  }
}
