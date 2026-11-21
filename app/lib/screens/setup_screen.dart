import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'sms_setup_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _total = 4;
  int _step = 0;
  bool _saving = false;
  bool _addBank = true;

  final _name = TextEditingController();
  final _cash = TextEditingController();
  final _bankName = TextEditingController(text: 'Bank of Baroda');
  final _bankLast4 = TextEditingController(text: '2261');
  final _bankBal = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _cash, _bankName, _bankLast4, _bankBal]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canContinue {
    if (_saving) return false;
    if (_step == 1) return _name.text.trim().isNotEmpty;
    if (_step == 2) return !_addBank || _bankName.text.trim().isNotEmpty;
    return true;
  }

  double _num(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step < _total - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    final settings = context.read<SettingsState>();
    final accounts = context.read<AccountsState>();
    final navigator = Navigator.of(context);

    await settings.setUserName(_name.text.trim());
    if (_addBank) {
      await accounts.save(Account(
        name: _bankName.text.trim(),
        type: AccountType.bank,
        bank: 'BOB',
        last4: _bankLast4.text.trim(),
        balance: _num(_bankBal.text),
        colorIndex: 0,
        balanceUpdatedAt: DateTime.now(),
      ));
    }
    await accounts.save(Account(
      name: 'Cash',
      type: AccountType.cash,
      balance: _num(_cash.text),
      colorIndex: 2,
      balanceUpdatedAt: DateTime.now(),
    ));
    await settings.completeOnboarding();
    navigator.pushAndRemoveUntil(
        fadeRoute(const SmsSetupScreen(fromOnboarding: true)), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _step > 0 ? 1 : 0,
                      child: IconButton(
                        onPressed:
                            _step > 0 ? () => setState(() => _step--) : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(
                          _total,
                          (i) => Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? AppColors.lavender
                                    : fin.divider,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 24, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: _stepBody(context),
                      ),
                    ),
                  ),
                ),
              ),
              PrimaryButton(
                label: _step == _total - 1 ? 'Start using FinUp' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _canContinue ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final fin = context.fin;
    switch (_step) {
      case 0:
        return _privacy(fin);
      case 1:
        return _nameStep(fin);
      case 2:
        return _accountsStep(fin);
      default:
        return _themeStep(context, fin);
    }
  }

  Widget _title(String t, String sub, FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: AppText.display(size: 28, color: fin.text)),
        const SizedBox(height: 10),
        Text(sub,
            style: TextStyle(color: fin.subtext, fontSize: 15, height: 1.5)),
      ],
    );
  }

  // ---------- Step 0: privacy ----------
  Widget _privacy(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Looping(
            duration: const Duration(milliseconds: 2400),
            builder: (context, t) => SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var k = 0; k < 2; k++) _ring((t + k * 0.5) % 1.0),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.lavender, AppColors.pink]),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        size: 44, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _title('Your data stays\non your phone',
            'FinUp works fully offline. Here is the promise:', fin),
        const SizedBox(height: 22),
        _promise(Icons.phone_android_rounded, 'Stored only on this device',
            'Nothing is uploaded anywhere.', fin),
        _promise(Icons.cloud_off_rounded, 'No servers, no sign-up',
            'No tracking and no ads.', fin),
        _promise(Icons.sms_rounded, 'SMS used only for transactions',
            'Only bank messages are read to log your spending.', fin),
        _promise(Icons.delete_outline_rounded, 'Delete anytime',
            'Wipe all data from Settings whenever you want.', fin),
      ],
    );
  }

  Widget _ring(double p) {
    return Opacity(
      opacity: 1 - p,
      child: Container(
        width: 92 + 88 * p,
        height: 92 + 88 * p,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 2),
        ),
      ),
    );
  }

  Widget _promise(IconData icon, String title, String sub, FinColors fin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.lavender),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: fin.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: fin.subtext, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 1: name ----------
  Widget _nameStep(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('What should we\ncall you?',
            'Just for greeting you on the home screen.', fin),
        const SizedBox(height: 28),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 18, color: fin.text),
          decoration: const InputDecoration(
            hintText: 'Your name',
            prefixIcon: Icon(Icons.person_rounded),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_canContinue) _next();
          },
        ),
      ],
    );
  }

  // ---------- Step 2: accounts ----------
  Widget _box(FinColors fin, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fin.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _accountsStep(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Set up your\naccounts',
          'Bank balance will update automatically from SMS once tracking is on. You can edit everything later.',
          fin,
        ),
        const SizedBox(height: 24),
        _box(
          fin,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.account_balance_rounded, AppColors.lavender),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Bank account',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: fin.text)),
                  ),
                  Switch(
                    value: _addBank,
                    onChanged: (v) => setState(() => _addBank = v),
                  ),
                ],
              ),
              if (_addBank) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _bankName,
                  decoration: InputDecoration(
                      labelText: 'Bank name', fillColor: fin.bg),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bankLast4,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Last 4 digits',
                          counterText: '',
                          fillColor: fin.bg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bankBal,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Balance',
                          prefixText: '₹ ',
                          fillColor: fin.bg,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _box(
          fin,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.payments_rounded, AppColors.pink),
                  const SizedBox(width: 12),
                  Text('Cash in hand',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: fin.text)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cash,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'How much cash do you have?',
                  prefixText: '₹ ',
                  fillColor: fin.bg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Step 3: theme ----------
  Widget _themeStep(BuildContext context, FinColors fin) {
    final settings = context.watch<SettingsState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Pick your look', 'Switch anytime from Settings.', fin),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                child: _themeTile(settings, ThemeMode.light, 'Light', fin)),
            const SizedBox(width: 12),
            Expanded(child: _themeTile(settings, ThemeMode.dark, 'Dark', fin)),
            const SizedBox(width: 12),
            Expanded(
                child: _themeTile(settings, ThemeMode.system, 'System', fin)),
          ],
        ),
      ],
    );
  }

  Widget _themeTile(
      SettingsState s, ThemeMode mode, String label, FinColors fin) {
    final selected = s.themeMode == mode;
    return GestureDetector(
      onTap: () => s.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fin.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.lavender : fin.divider,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.62,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: mode == ThemeMode.system
                    ? Row(children: [
                        Expanded(child: _mini(false)),
                        Expanded(child: _mini(true)),
                      ])
                    : _mini(mode == ThemeMode.dark),
              ),
            ),
            const SizedBox(height: 10),
            Text(label,
                style:
                    TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.lavender : fin.subtext,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(bool dark) {
    final c = dark ? FinColors.dark : FinColors.light;
    return Container(
      color: c.bg,
      child: Column(
        children: [
          Container(
            height: 46,
            color: c.hero,
            padding: const EdgeInsets.all(6),
            alignment: Alignment.bottomLeft,
            child: Container(width: 30, height: 6, color: Colors.white70),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradients[0],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(3),
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
