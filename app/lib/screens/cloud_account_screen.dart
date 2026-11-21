import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cloud/api.dart';
import '../cloud/sync.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CloudAccountScreen extends StatefulWidget {
  const CloudAccountScreen({super.key});

  @override
  State<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends State<CloudAccountScreen> {
  bool _signedIn = false;
  String? _email;
  String? _name;
  int _revision = 0;
  bool _dirty = false;
  bool _busy = false;
  String? _msg;
  SyncSnapshot? _conflict;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _signup = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final s = CloudSync.instance;
    final signed = await s.isSignedIn;
    final email = await s.email;
    final name = await s.displayName;
    final rev = await s.revision;
    final dirty = await s.isDirty;
    if (!mounted) return;
    setState(() {
      _signedIn = signed;
      _email = email;
      _name = name;
      _revision = rev;
      _dirty = dirty;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _refreshLocal() async {
    if (!mounted) return;
    await context.read<AccountsState>().load();
    await context.read<TxnState>().load();
  }

  Future<void> _auth() async {
    setState(() {
      _busy = true;
      _msg = null;
      _conflict = null;
    });
    try {
      final CloudSyncResult res;
      if (_signup) {
        res = await CloudSync.instance.signup(
          name: _nameCtrl.text.trim().isEmpty
              ? 'FinUp user'
              : _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        res = await CloudSync.instance.login(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }
      if (res.conflict != null) {
        setState(() => _conflict = res.conflict);
      }
      await _refreshLocal();
      await _reload();
      if (mounted) {
        setState(() => _msg = res.message);
        if (res.ok) _snack(res.message);
      }
    } catch (e) {
      if (mounted) setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync({bool force = false}) async {
    setState(() {
      _busy = true;
      _msg = null;
      if (!force) _conflict = null;
    });
    final res = await CloudSync.instance.sync(force: force);
    if (res.conflict != null) {
      setState(() => _conflict = res.conflict);
    } else if (res.ok) {
      await _refreshLocal();
    }
    await _reload();
    if (mounted) {
      setState(() {
        _busy = false;
        _msg = res.message;
      });
      _snack(res.message);
    }
  }

  Future<void> _keepCloud() async {
    final c = _conflict;
    if (c == null) return;
    setState(() => _busy = true);
    final res = await CloudSync.instance.applyConflictKeepCloud(c);
    await _refreshLocal();
    await _reload();
    if (mounted) {
      setState(() {
        _busy = false;
        _conflict = null;
        _msg = res.message;
      });
      _snack(res.message);
    }
  }

  Future<void> _keepLocal() async {
    final c = _conflict;
    if (c == null) return;
    setState(() => _busy = true);
    final res = await CloudSync.instance.applyConflictKeepLocal(c);
    await _refreshLocal();
    await _reload();
    if (mounted) {
      setState(() {
        _busy = false;
        _conflict = res.conflict;
        _msg = res.message;
      });
      _snack(res.message);
    }
  }

  Future<void> _signOut() async {
    await CloudSync.instance.signOut();
    await _reload();
    if (mounted) _snack('Signed out of cloud sync');
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud sync'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator())
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Sign in so FinUp on this phone and the web app stay in sync at api.finup.yashchauhan.pro. You can still use FinUp fully offline; sync runs when you open the app and about every hour.',
            style: TextStyle(color: fin.subtext, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (!_signedIn) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Log in')),
                ButtonSegment(value: true, label: Text('Sign up')),
              ],
              selected: {_signup},
              onSelectionChanged: (v) => setState(() => _signup = v.first),
            ),
            const SizedBox(height: 14),
            if (_signup)
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            if (_signup) const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _signup ? 'Create account & sync' : 'Log in & sync',
              icon: Icons.cloud_sync_rounded,
              onPressed: _busy ? null : _auth,
            ),
          ] else ...[
            Material(
              color: fin.card,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name?.isNotEmpty == true ? _name! : 'FinUp account',
                        style: TextStyle(
                            color: fin.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(_email ?? '', style: TextStyle(color: fin.subtext)),
                    const SizedBox(height: 10),
                    Text(
                      'Revision $_revision · ${_dirty ? 'Local changes pending' : 'In sync'}',
                      style: TextStyle(color: fin.subtext, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Sync now',
              icon: Icons.sync_rounded,
              onPressed: _busy ? null : () => _sync(),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
          if (_conflict != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sync conflict',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.expense)),
                  const SizedBox(height: 8),
                  Text(
                    'Cloud revision ${_conflict!.revision} changed on another device (web or phone). Choose which copy to keep.',
                    style: TextStyle(color: fin.subtext, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _keepCloud,
                          child: const Text('Keep cloud'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _keepLocal,
                          child: const Text('Keep this phone'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!, style: TextStyle(color: fin.subtext, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
