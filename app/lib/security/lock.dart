import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../theme.dart';
import '../widgets/logo.dart';

class LockPrefs {
  static String _hash(String pin) =>
      sha256.convert(utf8.encode('finup:$pin')).toString();

  static Future<bool> enabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pinHash') != null;
  }

  static Future<bool> biometric() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('bioOn') ?? false;
  }

  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pinHash', _hash(pin));
  }

  static Future<void> setBiometric(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bioOn', v);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('pinHash');
    await p.remove('bioOn');
  }

  static Future<bool> check(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pinHash') == _hash(pin);
  }
}

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  static int _suspend = 0;

  /// Use while opening system screens (file picker, share sheet, fingerprint)
  /// so returning from them does not lock the app.
  static Future<T> suspendWhile<T>(Future<T> Function() f) async {
    _suspend++;
    try {
      return await f();
    } finally {
      Future.delayed(const Duration(seconds: 2), () => _suspend--);
    }
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final on = p.getString('pinHash') != null && (p.getBool('onboarded') ?? false);
    if (on && mounted) setState(() => _locked = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    final at = _pausedAt;
    _pausedAt = null;
    if (at == null || AppLockGate._suspend > 0) return;
    if (DateTime.now().difference(at) < const Duration(seconds: 30)) return;
    if (await LockPrefs.enabled() && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_locked)
        Positioned.fill(
          child: LockScreen(onUnlocked: () => setState(() => _locked = false)),
        ),
    ]);
  }
}

class PinDots extends StatelessWidget {
  final int length;
  final bool error;
  const PinDots({super.key, required this.length, this.error = false});

  @override
  Widget build(BuildContext context) {
    final c = error ? AppColors.expense : AppColors.lavender;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? c : Colors.transparent,
            border: Border.all(color: error ? c : Colors.white54, width: 2),
          ),
        ),
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final Widget? extra;
  const PinPad({super.key, required this.onKey, this.extra});

  Widget _btn(String k) {
    return SizedBox(
      width: 76,
      height: 76,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(k);
        },
        child: Center(
          child: k == '<'
              ? const Icon(Icons.backspace_outlined, color: Colors.white)
              : Text(k,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(children: [
      for (final r in rows)
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final k in r) _btn(k)]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        SizedBox(width: 76, height: 76, child: Center(child: extra)),
        _btn('0'),
        _btn('<'),
      ]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  int _errors = 0;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBio());
  }

  Future<void> _initBio() async {
    final on = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    if (!mounted) return;
    setState(() => _bio = on && can);
    if (_bio) _authBio();
  }

  Future<void> _authBio() async {
    final ok = await AppLockGate.suspendWhile(
        () => Native.authenticate('Use your fingerprint to unlock'));
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _key(String k) async {
    if (k == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin = '$_pin$k');
    if (_pin.length == 4) {
      final ok = await LockPrefs.check(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errors++;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(children: [
          const Spacer(),
          const FinUpLogo(size: 64),
          const SizedBox(height: 18),
          Text('Enter your PIN',
              style: AppText.display(size: 20, color: Colors.white)),
          const SizedBox(height: 26),
          TweenAnimationBuilder<double>(
            key: ValueKey(_errors),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            builder: (context, v, child) => Transform.translate(
              offset: Offset(
                  _errors == 0 ? 0 : math.sin(v * math.pi * 6) * 14 * (1 - v), 0),
              child: child,
            ),
            child: PinDots(length: _pin.length),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: _errors > 0
                ? const Text('Wrong PIN, try again',
                    style: TextStyle(color: AppColors.pink))
                : null,
          ),
          const Spacer(),
          PinPad(
            onKey: _key,
            extra: _bio
                ? IconButton(
                    onPressed: _authBio,
                    icon: const Icon(Icons.fingerprint_rounded,
                        color: AppColors.lavender, size: 36))
                : null,
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirm = false;
  bool _error = false;

  Future<void> _key(String k) async {
    if (k == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin = '$_pin$k';
      _error = false;
    });
    if (_pin.length < 4) return;
    await Future.delayed(const Duration(milliseconds: 150));
    if (!_confirm) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirm = true;
      });
    } else if (_pin == _first) {
      final nav = Navigator.of(context);
      await LockPrefs.setPin(_pin);
      nav.pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _first = '';
        _confirm = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('App lock'),
      ),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          const FinUpLogo(size: 56),
          const SizedBox(height: 18),
          Text(_confirm ? 'Confirm your PIN' : 'Create a 4-digit PIN',
              style: AppText.display(size: 20, color: Colors.white)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error
                  ? 'PINs did not match. Start again.'
                  : 'If you forget it, the only way back in is clearing app data, so keep a backup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _error ? AppColors.pink : Colors.white54, height: 1.4),
            ),
          ),
          const SizedBox(height: 26),
          PinDots(length: _pin.length, error: _error),
          const Spacer(),
          PinPad(onKey: _key),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}
