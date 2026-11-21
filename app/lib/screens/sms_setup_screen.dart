import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../native.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

class SmsSetupScreen extends StatefulWidget {
  final bool fromOnboarding;
  const SmsSetupScreen({super.key, this.fromOnboarding = false});

  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  int _months = 3;
  int _phase = 0; // 0 intro, 1 scanning, 2 done, 3 denied
  int _found = 0;

  Future<void> _start() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final settings = context.read<SettingsState>();
    final ok = await Native.requestSms();
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = 3);
      return;
    }
    setState(() => _phase = 1);
    final since = DateTime.now()
        .subtract(Duration(days: 30 * _months))
        .millisecondsSinceEpoch;
    final n = await txns.sync(accounts, sinceMs: since);
    await Native.requestNotifications();
    await Native.scheduleReminder(settings.reminderTime.hour,
        settings.reminderTime.minute, await ReminderPrefs.isOn());
    if (!mounted) return;
    setState(() {
      _found = n;
      _phase = 2;
    });
  }

  void _finish() {
    if (widget.fromOnboarding) {
      Navigator.of(context)
          .pushAndRemoveUntil(fadeRoute(const HomeShell()), (r) => false);
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _chip(int months) {
    final sel = _months == months;
    return GestureDetector(
      onTap: () => setState(() => _months = months),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(colors: [AppColors.lavender, AppColors.pink])
              : null,
          color: sel ? null : const Color(0xFF1B1B25),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? Colors.transparent : Colors.white12),
        ),
        child: Text('$months ${months == 1 ? 'month' : 'months'}',
            style: TextStyle(
                color: sel ? AppColors.ink : Colors.white70,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _body() {
    const white60 = TextStyle(color: Colors.white60, fontSize: 15, height: 1.5);
    switch (_phase) {
      case 1:
        return Column(
          key: const ValueKey(1),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Looping(
              duration: const Duration(milliseconds: 1600),
              builder: (context, t) => Transform.rotate(
                angle: t * 2 * math.pi,
                child: const FinUpLogo(size: 96),
              ),
            ),
            const SizedBox(height: 28),
            Text('Reading your bank SMS…',
                style: AppText.display(size: 22, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Everything stays on this phone.', style: white60),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.income, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 24),
            Text('Found $_found transactions',
                textAlign: TextAlign.center,
                style: AppText.display(size: 24, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
                'They are waiting in your review inbox. Your bank balance is updated too.',
                textAlign: TextAlign.center,
                style: white60),
            const SizedBox(height: 32),
            PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _finish),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey(3),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_failed_rounded, color: AppColors.pink, size: 64),
            const SizedBox(height: 20),
            Text('SMS access was denied',
                style: AppText.display(size: 22, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
                'Open settings, tap Permissions, then allow SMS for FinUp. You can still add entries by hand.',
                textAlign: TextAlign.center,
                style: white60),
            const SizedBox(height: 28),
            PrimaryButton(
                label: 'Open settings',
                icon: Icons.settings_rounded,
                onPressed: () => Native.openSettings()),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => setState(() => _phase = 0),
                child: const Text('Try again',
                    style: TextStyle(color: Colors.white70))),
            TextButton(
                onPressed: _finish,
                child: const Text('Skip for now',
                    style: TextStyle(color: Colors.white38))),
          ],
        );
      default:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
                child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: SmsArt()))),
            Text('Turn on\nauto-tracking',
                style: AppText.display(size: 30, color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
                'FinUp reads only bank transaction SMS, on this phone, to log amount, time, account and balance. Nothing is uploaded.',
                style: white60),
            const SizedBox(height: 20),
            const Text('Import past messages from',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              _chip(1),
              const SizedBox(width: 8),
              _chip(3),
              const SizedBox(width: 8),
              _chip(6),
            ]),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Allow SMS access',
                icon: Icons.sms_rounded,
                onPressed: _start),
            Center(
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip for now',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          const Positioned.fill(
            child: Opacity(
                opacity: 0.3,
                child: OrbitBackground(center: Alignment(0.3, -0.7))),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _body(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
