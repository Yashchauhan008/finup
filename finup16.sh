#!/usr/bin/env bash
# FinUp Part 16 — Cloud sync (2-way with api.finup.yashchauhan.pro + web)
# Sources live in parts/16-cloud/ so they survive `rm -rf app` in finup.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/app"

PARTS="$ROOT/parts/16-cloud"
[ -d "$PARTS" ] || { echo "missing $PARTS"; exit 1; }

############################ pubspec: http + uuid ############################
if ! grep -q '^  http:' pubspec.yaml; then
  sed -i "s#  path_provider: ^2.1.4#  path_provider: ^2.1.4\n  http: ^1.2.2\n  uuid: ^4.5.1#" pubspec.yaml
fi
grep -q '^  http:' pubspec.yaml || { echo "ERROR: http pubspec patch failed"; exit 1; }
grep -q '^  uuid:' pubspec.yaml || { echo "ERROR: uuid pubspec patch failed"; exit 1; }
echo "ok pubspec http+uuid"

############################ copy cloud sources ############################
mkdir -p lib/cloud lib/screens
cp "$PARTS/api.dart" lib/cloud/api.dart
cp "$PARTS/sync.dart" lib/cloud/sync.dart
cp "$PARTS/cloud_account_screen.dart" lib/screens/cloud_account_screen.dart
echo "ok cloud source files"

python3 <<'PY'
from pathlib import Path
from typing import Optional

def must(p: str) -> Path:
    path = Path(p)
    if not path.exists():
        raise SystemExit(f'missing {p}')
    return path

def read(p: str) -> str:
    return must(p).read_text()

def write(p: str, text: str):
    Path(p).write_text(text)

def replace_once(path: str, old: str, new: str, already: Optional[str] = None):
    text = read(path)
    # If marker already present, never re-apply (avoids duplicate imports on re-run).
    if already and already in text:
        print(f'skip {path}')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:280]}\n---')
    write(path, text.replace(old, new, 1))
    print(f'patched {path}')

def ensure(path: str, needle: str, label: str):
    if needle not in read(path):
        raise SystemExit(f'missing {label} in {path}')
    print(f'ok {label}')

# =============================================================================
# backup.dart — include deleted_refs + resilient import
# =============================================================================
write('lib/data/backup.dart', r'''import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';

const kFinupSyncTables = [
  'accounts',
  'categories',
  'transactions',
  'people',
  'ledger',
  'rules',
  'budgets',
  'goals',
  'tags',
  'txn_tags',
  'receipts',
  'deleted_refs',
];

extension Backup on AppDatabase {
  Future<String> exportJson() async {
    final data = <String, Object?>{};
    for (final t in kFinupSyncTables) {
      try {
        data[t] = await db.query(t);
      } catch (_) {
        data[t] = <Map<String, Object?>>[];
      }
    }
    return jsonEncode({
      'app': 'FinUp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': data,
    });
  }

  Future<bool> importJson(String json) async {
    final root = jsonDecode(json);
    if (root is! Map || root['app'] != 'FinUp' || root['tables'] is! Map) {
      return false;
    }
    final tables = root['tables'] as Map;
    await db.transaction((txn) async {
      for (final t in kFinupSyncTables) {
        try {
          await txn.delete(t);
        } catch (_) {}
      }
      for (final t in kFinupSyncTables) {
        final rows = tables[t];
        if (rows is! List) continue;
        for (final r in rows) {
          if (r is! Map) continue;
          final map = <String, Object?>{};
          r.forEach((k, v) {
            if (v == null || v is num || v is String || v is bool) {
              map[k.toString()] = v;
            } else {
              map[k.toString()] = v.toString();
            }
          });
          try {
            await txn.insert(t, map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        }
      }
    });
    return true;
  }

  Future<String> exportCsv() async {
    final cats = {for (final c in await categories()) c.id: c.name};
    final accs = {for (final a in await db.query('accounts')) a['id']: a['name']};
    final ppl = {for (final p in await db.query('people')) p['id']: p['name']};
    final rows = await db.query('transactions', orderBy: 'occurred_at DESC');
    final b = StringBuffer(
        'Date,Type,Amount,Category,Account,To account,Payee,Person,Note,Status\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int);
      b.writeln([
        d.toIso8601String().substring(0, 16).replaceAll('T', ' '),
        r['type'],
        r['amount'],
        cats[r['category_id']] ?? '',
        accs[r['account_id']] ?? '',
        accs[r['to_account_id']] ?? '',
        r['counterparty'],
        ppl[r['person_id']] ?? '',
        r['note'],
        r['status'],
      ].map(esc).join(','));
    }
    return b.toString();
  }

  Future<void> wipeAll() async {
    for (final t in [
      'accounts',
      'transactions',
      'people',
      'ledger',
      'rules',
      'budgets',
      'goals',
      'tags',
      'txn_tags',
      'receipts',
      'deleted_refs',
    ]) {
      try {
        await db.delete(t);
      } catch (_) {}
    }
  }
}
''')
print('ok backup.dart')

# =============================================================================
# settings_screen.dart
# =============================================================================
replace_once(
    'lib/screens/settings_screen.dart',
    "import 'about_screen.dart';\nimport 'account_editor.dart';\nimport 'extra_settings.dart';",
    "import 'about_screen.dart';\nimport 'account_editor.dart';\nimport 'cloud_account_screen.dart';\nimport 'extra_settings.dart';",
    already="import 'cloud_account_screen.dart';",
)
replace_once(
    'lib/screens/settings_screen.dart',
    "import 'sms_setup_screen.dart';\n",
    "import 'sms_setup_screen.dart';\nimport '../cloud/sync.dart';\n",
    already="import '../cloud/sync.dart';",
)
replace_once(
    'lib/screens/settings_screen.dart',
    '''  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rem = await ReminderPrefs.isOn();
    final lock = await LockPrefs.enabled();
    final bio = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    if (!mounted) return;
    setState(() {
      _remOn = rem;
      _lockOn = lock;
      _bioOn = bio;
      _canBio = can;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));
''',
    '''  bool _busy = false;
  bool _cloudOn = false;
  String? _cloudEmail;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rem = await ReminderPrefs.isOn();
    final lock = await LockPrefs.enabled();
    final bio = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    final cloudOn = await CloudSync.instance.isSignedIn;
    final cloudEmail = await CloudSync.instance.email;
    if (!mounted) return;
    setState(() {
      _remOn = rem;
      _lockOn = lock;
      _bioOn = bio;
      _canBio = can;
      _cloudOn = cloudOn;
      _cloudEmail = cloudEmail;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(fadeRoute(page));
  }
''',
    already='bool _cloudOn = false',
)
replace_once(
    'lib/screens/settings_screen.dart',
    '''          _Section(title: 'Profile', children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.userName.isEmpty ? 'Not set' : s.userName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editName(s),
            ),
          ]),
''',
    '''          _Section(title: 'Profile', children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.userName.isEmpty ? 'Not set' : s.userName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editName(s),
            ),
            ListTile(
              leading: Icon(Icons.cloud_sync_rounded,
                  color: _cloudOn ? AppColors.income : null),
              title: Text(_cloudOn ? 'Cloud sync on' : 'Cloud sync'),
              subtitle: Text(_cloudOn
                  ? (_cloudEmail ?? 'Signed in · 2-way with web')
                  : 'Sign in to sync with FinUp web'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await _open(const CloudAccountScreen());
                if (mounted) _init();
              },
            ),
          ]),
''',
    already='Cloud sync on',
)
replace_once(
    'lib/screens/settings_screen.dart',
    '''    if (ok) {
      await accounts.load();
      await txns.load();
    }
    if (mounted) _snack(ok ? 'Backup restored.' : 'That file is not a FinUp backup.');
  }
''',
    '''    if (ok) {
      await CloudSync.instance.markDirty();
      await accounts.load();
      await txns.load();
      if (await CloudSync.instance.isSignedIn) {
        await CloudSync.instance.sync();
      }
    }
    if (mounted) _snack(ok ? 'Backup restored.' : 'That file is not a FinUp backup.');
  }
''',
    already='CloudSync.instance.markDirty()',
)

# =============================================================================
# home_shell.dart — sync on resume
# =============================================================================
replace_once(
    'lib/screens/home_shell.dart',
    "import '../data/db.dart';\n",
    "import '../cloud/sync.dart';\nimport '../data/db.dart';\n",
    already="import '../cloud/sync.dart';",
)
replace_once(
    'lib/screens/home_shell.dart',
    '''class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    await handleLaunchAction(context);
    if (!mounted) return;
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    await txns.load();
    if (txns.smsEnabled) {
      await Native.ensureSmsReceive();
      await txns.sync(accounts);
    }
    if (mounted) UpdateService.autoCheck(context);
  }
''',
    '''class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  DateTime? _lastCloudSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  bool get _cloudDue {
    final last = _lastCloudSync;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(hours: 1);
  }

  Future<void> _cloudSyncIfNeeded({bool force = false}) async {
    if (!await CloudSync.instance.isSignedIn) return;
    if (!force && !_cloudDue && !(await CloudSync.instance.isDirty)) return;
    final res = await CloudSync.instance.sync();
    _lastCloudSync = DateTime.now();
    if (!mounted) return;
    if (res.ok && (res.message.contains('Pulled') || res.message.contains('Synced'))) {
      await context.read<AccountsState>().load();
      await context.read<TxnState>().load();
    }
  }

  Future<void> _sync() async {
    if (!mounted) return;
    await handleLaunchAction(context);
    if (!mounted) return;
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    await txns.load();
    if (txns.smsEnabled) {
      await Native.ensureSmsReceive();
      await txns.sync(accounts);
    }
    await _cloudSyncIfNeeded(force: true);
    if (mounted) UpdateService.autoCheck(context);
  }
''',
    already='_cloudSyncIfNeeded',
)

# =============================================================================
# txn_state.dart — mark dirty on writes
# =============================================================================
replace_once(
    'lib/state/txn_state.dart',
    "import '../data/db.dart';\n",
    "import '../cloud/sync.dart';\nimport '../data/db.dart';\n",
    already="import '../cloud/sync.dart';",
)
replace_once(
    'lib/state/txn_state.dart',
    '''      n = await SmsSync.run(sinceMs: sinceMs);
      await AppDatabase.instance.autoLinkPeople();
      await applyPendingCategories();
      await AppDatabase.instance.autoTagTrips();
    } catch (_) {}
''',
    '''      n = await SmsSync.run(sinceMs: sinceMs);
      await AppDatabase.instance.autoLinkPeople();
      await applyPendingCategories();
      await AppDatabase.instance.autoTagTrips();
      if (n > 0) await CloudSync.instance.markDirty();
    } catch (_) {}
''',
    already='if (n > 0) await CloudSync.instance.markDirty()',
)
replace_once(
    'lib/state/txn_state.dart',
    '''  Future<void> save(AccountsState accounts, Txn t, {Txn? old}) async {
    if (old == null) {
      await _db.addTxn(t);
    } else {
      await _db.editTxn(old, t);
    }
    await accounts.load();
    await load();
  }

  Future<void> delete(AccountsState accounts, Txn t) async {
    await _db.deleteTxn(t);
    await accounts.load();
    await load();
  }

  Future<void> categorize(Txn t, int categoryId, {bool remember = true}) async {
    await _db.markReviewed(t.id!, categoryId);
    final key = t.counterparty?.trim().toLowerCase();
    if (remember && key != null && key.isNotEmpty) {
      await _db.addRule(key, categoryId);
      await _db.applyRuleToPending(key, categoryId);
    }
    await load();
  }

  Future<void> rememberRule(String payee, int categoryId) async {
    await _db.addRule(payee, categoryId);
    await _db.applyRuleToPending(payee, categoryId);
    await load();
  }

  Future<void> markAllReviewed() async {
    await _db.markAllReviewed();
    await load();
  }
}
''',
    '''  Future<void> save(AccountsState accounts, Txn t, {Txn? old}) async {
    if (old == null) {
      await _db.addTxn(t);
    } else {
      await _db.editTxn(old, t);
    }
    await CloudSync.instance.markDirty();
    await accounts.load();
    await load();
  }

  Future<void> delete(AccountsState accounts, Txn t) async {
    await _db.deleteTxn(t);
    await CloudSync.instance.markDirty();
    await accounts.load();
    await load();
  }

  Future<void> categorize(Txn t, int categoryId, {bool remember = true}) async {
    await _db.markReviewed(t.id!, categoryId);
    final key = t.counterparty?.trim().toLowerCase();
    if (remember && key != null && key.isNotEmpty) {
      await _db.addRule(key, categoryId);
      await _db.applyRuleToPending(key, categoryId);
    }
    await CloudSync.instance.markDirty();
    await load();
  }

  Future<void> rememberRule(String payee, int categoryId) async {
    await _db.addRule(payee, categoryId);
    await _db.applyRuleToPending(payee, categoryId);
    await CloudSync.instance.markDirty();
    await load();
  }

  Future<void> markAllReviewed() async {
    await _db.markAllReviewed();
    await CloudSync.instance.markDirty();
    await load();
  }
}
''',
    already='await CloudSync.instance.markDirty();\n    await accounts.load();\n    await load();\n  }\n\n  Future<void> delete',
)

# =============================================================================
# app_state.dart — mark dirty on account edits
# =============================================================================
replace_once(
    'lib/state/app_state.dart',
    "import '../data/db.dart';\n",
    "import '../cloud/sync.dart';\nimport '../data/db.dart';\n",
    already="import '../cloud/sync.dart';",
)
replace_once(
    'lib/state/app_state.dart',
    '''  Future<void> save(Account a) async {
    if (a.id == null) {
      await _db.insertAccount(a);
    } else {
      await _db.updateAccount(a);
    }
    await load();
  }

  Future<void> remove(int id) async {
    await _db.removeAccount(id);
    await load();
  }
}
''',
    '''  Future<void> save(Account a) async {
    if (a.id == null) {
      await _db.insertAccount(a);
    } else {
      await _db.updateAccount(a);
    }
    await CloudSync.instance.markDirty();
    await load();
  }

  Future<void> remove(int id) async {
    await _db.removeAccount(id);
    await CloudSync.instance.markDirty();
    await load();
  }
}
''',
    already='await CloudSync.instance.markDirty();\n    await load();\n  }\n\n  Future<void> remove',
)

# =============================================================================
# about / legal copy
# =============================================================================
replace_once(
    'lib/screens/about_screen.dart',
    "subtitle: Text('No cloud, no tracking, no ads'),",
    "subtitle: Text('Optional cloud sync · no ads'),",
    already='Optional cloud sync',
)
replace_once(
    'lib/screens/legal_screen.dart',
    "subtitle: Text('No cloud, no tracking, no ads'),",
    "subtitle: Text('Optional cloud sync · no ads'),",
    already='Optional cloud sync',
)

checks = [
    ('lib/cloud/api.dart', 'kFinupApiBase', 'api'),
    ('lib/cloud/sync.dart', 'class CloudSync', 'sync'),
    ('lib/screens/cloud_account_screen.dart', 'Sync now', 'sync now button'),
    ('lib/screens/settings_screen.dart', 'CloudAccountScreen', 'settings cloud row'),
    ('lib/screens/home_shell.dart', '_cloudSyncIfNeeded', 'home cloud sync'),
    ('pubspec.yaml', 'http:', 'http dep'),
]
for path, needle, label in checks:
    ensure(path, needle, label)

print('FinUp Part 16 complete — cloud sync')
PY
