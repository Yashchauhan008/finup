import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String updated;
  final List<(String, String)> sections;

  const LegalScreen(
      {super.key, required this.title, required this.updated, required this.sections});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text('Last updated: $updated', style: TextStyle(color: fin.subtext)),
          const SizedBox(height: 12),
          for (final s in sections) ...[
            const SizedBox(height: 14),
            Text(s.$1,
                style: TextStyle(
                    color: fin.text, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(s.$2, style: TextStyle(color: fin.subtext, height: 1.55, fontSize: 14.5)),
          ],
        ],
      ),
    );
  }
}

const termsSections = <(String, String)>[
  ('1. About FinUp',
      'FinUp is a personal expense manager that runs entirely on your phone. It is intended for personal, non-commercial use by the owner of the device.'),
  ('2. Your data and backups',
      'All information you enter or that FinUp reads is stored only on this device. You are responsible for keeping backups. Uninstalling the app or clearing its data permanently deletes everything unless you have exported a backup file.'),
  ('3. SMS reading',
      'With your permission, FinUp reads SMS messages on this device to detect bank transactions. Automatic reading can occasionally misread amounts, accounts or balances. Always check important figures against your official bank statement.'),
  ('4. Not financial advice',
      'Charts, budgets, goals and summaries are for personal tracking only. They are not financial, tax, legal or investment advice.'),
  ('5. People ledger',
      'Amounts recorded with other people are personal notes. FinUp does not collect, request or move money, and entries are not legal proof of a debt.'),
  ('6. App lock',
      'If you set a PIN and forget it, the only way to regain access is to clear the app data, which deletes all records. Keep a backup.'),
  ('7. No warranty',
      'FinUp is provided "as is", without warranties of any kind, including accuracy, availability or fitness for a particular purpose.'),
  ('8. Limitation of liability',
      'To the extent permitted by law, the developer is not liable for any loss arising from use of the app, including data loss or decisions made based on its information.'),
  ('9. Changes',
      'These terms may change when the app is updated. Continuing to use FinUp after an update means you accept the updated terms.'),
  ('10. Governing law', 'These terms are governed by the laws of India.'),
];

const privacySections = <(String, String)>[
  ('Summary',
      'FinUp has no servers, no user accounts, no ads and no analytics. Your financial data never leaves your phone unless you choose to share or export it.'),
  ('SMS permission',
      'FinUp reads your SMS inbox only to find bank transaction messages (amount, account digits, UPI ID, reference number, balance, date and time). Messages without a money amount are skipped before they reach the app. Other messages are never stored.'),
  ('What is stored',
      'Accounts, transactions, categories, rules, budgets, goals, people you add (names, optional phone numbers and UPI IDs) and your settings. Everything is kept in a private database inside the app on this device.'),
  ('Notifications',
      'Used only for your daily review reminder at the time you choose.'),
  ('Fingerprint',
      'Fingerprint unlock is handled entirely by Android. FinUp never receives or stores your fingerprint data. Your PIN is stored only as a one-way hash.'),
  ('Internet',
      'The app may use the internet only to download its fonts. No financial or personal data is ever sent.'),
  ('Sharing and exports',
      'Data leaves the app only when you tap Share, Backup or Export, and only to the place you pick. Shared statement images are also saved to Pictures/FinUp on your phone.'),
  ('Your control',
      'You can export a CSV, back up or restore your data, delete everything from Settings, and withdraw SMS or notification permission at any time in Android settings.'),
  ('Contact',
      'This copy of FinUp is built and maintained by its owner for personal use.'),
];

class AboutFinUpScreen extends StatelessWidget {
  const AboutFinUpScreen({super.key});

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
          Center(
              child: Text('Version 2.0.0', style: TextStyle(color: fin.subtext))),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your money, auto-tracked. Private. Offline. Yours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fin.subtext, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: fin.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
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
                subtitle: Text('Optional cloud sync · no ads'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
