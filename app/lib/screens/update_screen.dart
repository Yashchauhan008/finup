import 'package:flutter/material.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _checking = true;
  UpdateInfo? _info;
  String _curName = '';
  int _cur = 0;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _msg = null;
    });
    final (name, code) = await Native.appInfo();
    final info = await UpdateService.latest();
    if (!mounted) return;
    setState(() {
      _curName = name;
      _cur = code;
      _info = info;
      _checking = false;
      if (info == null) {
        _msg =
            'Could not reach GitHub releases. Check your internet connection and try again.';
      }
    });
  }

  bool get _hasUpdate => _info != null && _info!.build > _cur;

  Future<void> _openDownload() async {
    final url = (_info?.apkUrl.isNotEmpty == true)
        ? _info!.apkUrl
        : UpdateService.pageUrl;
    final ok = await AppLockGate.suspendWhile(() => Native.openUrl(url));
    if (!mounted) return;
    setState(() {
      final size = _info?.sizeLabel;
      _msg = ok
          ? (size == null || size.isEmpty
              ? 'Browser opened. Wait until FinUp.apk finishes (about 39 MB), then install. If it still says App not installed: Backup → Uninstall FinUp → install the APK → Restore.'
              : 'Browser opened. Wait until FinUp.apk is fully $size, then install. If it still says App not installed: Backup → Uninstall FinUp → install → Restore.')
          : 'Could not open the download page. Try again, or visit GitHub releases manually.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          const Center(child: FinUpLogo(size: 84)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _checking
                  ? 'Checking for updates…'
                  : (_hasUpdate
                      ? 'Update available'
                      : (_info == null ? 'Could not check' : 'You are up to date')),
              style: AppText.display(size: 22, color: fin.text),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Installed: ${_curName.isEmpty ? '-' : _curName} (build $_cur)',
              style: TextStyle(color: fin.subtext),
            ),
          ),
          const SizedBox(height: 24),
          if (_checking) const Center(child: CircularProgressIndicator()),
          if (_hasUpdate) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_info!.name,
                      style: TextStyle(
                          color: fin.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                      _info!.sizeLabel.isEmpty
                          ? 'Build ${_info!.build}'
                          : 'Build ${_info!.build} · ${_info!.sizeLabel}',
                      style: TextStyle(color: fin.subtext)),
                  if (_info!.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("What's new",
                        style: TextStyle(
                            color: fin.text, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_info!.notes,
                        style: TextStyle(color: fin.subtext, height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Open download page',
              icon: Icons.open_in_browser_rounded,
              onPressed: _openDownload,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(18)),
              child: Text(
                'If Android says “App not installed” with no reason:\n'
                '1. In FinUp → Settings → Backup (save the file somewhere safe).\n'
                '2. Uninstall FinUp completely.\n'
                '3. Download FinUp.apk again and wait until the file is ~${_info?.sizeLabel.isNotEmpty == true ? _info!.sizeLabel : '39 MB'} (not a tiny HTML file).\n'
                '4. Install the APK, open FinUp, then Settings → Restore from backup.\n\n'
                'Android hides the real cause. Almost always it is either a half-finished download, or the old FinUp was signed with a different key so Android blocks the update.',
                style: TextStyle(color: fin.subtext, height: 1.45, fontSize: 13),
              ),
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: fin.subtext, height: 1.5)),
          ],
          const SizedBox(height: 24),
          if (!_checking)
            Center(
              child: TextButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check again')),
            ),
          Center(
            child: TextButton.icon(
              onPressed: () => AppLockGate.suspendWhile(
                  () => Native.shareText(UpdateService.shareText)),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share FinUp'),
            ),
          ),
        ],
      ),
    );
  }
}
