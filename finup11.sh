#!/usr/bin/env bash
# FinUp Part 11 — Fix updates: use public finup releases + clearer install guidance
set -euo pipefail
cd app

python3 <<'PY'
from pathlib import Path
from typing import Optional

def must(path: str) -> Path:
    p = Path(path)
    if not p.exists():
        raise SystemExit(f'missing {path}')
    return p

def replace_once(path: str, old: str, new: str, already: Optional[str] = None):
    text = must(path).read_text()
    marker = already or new[:80]
    if already and already in text and old not in text:
        print(f'skip {path}')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:220]}\n---')
    must(path).write_text(text.replace(old, new, 1))
    print(f'patched {path}')

# Point updater at the public finup repo (finup-releases does not exist; RELEASES_TOKEN empty).
replace_once(
    'lib/update/updater.dart',
    '''class UpdateInfo {
  final int build;
  final String name;
  final String notes;
  final String apkUrl;
  const UpdateInfo(this.build, this.name, this.notes, this.apkUrl);
}

class UpdateService {
  static const repo = 'Yashchauhan008/finup-releases';
  static const pageUrl = 'https://github.com/$repo/releases/latest';
  static const shareText =
      'FinUp - my private, offline expense manager. Download the latest APK: $pageUrl';

  static Future<UpdateInfo?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'FinUp');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString();
      final build = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      String? url;
      final assets = j['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map) {
            final n = (a['name'] ?? '').toString().toLowerCase();
            if (n.endsWith('.apk')) {
              url = a['browser_download_url']?.toString();
              break;
            }
          }
        }
      }
      if (url == null) return null;
      return UpdateInfo(build, (j['name'] ?? tag).toString(),
          (j['body'] ?? '').toString(), url);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }''',
    '''class UpdateInfo {
  final int build;
  final String name;
  final String notes;
  final String apkUrl;
  final int? apkBytes;
  const UpdateInfo(this.build, this.name, this.notes, this.apkUrl, {this.apkBytes});

  String get sizeLabel {
    final b = apkBytes;
    if (b == null || b <= 0) return '';
    if (b >= 1000000) return '${(b / 1000000).toStringAsFixed(0)} MB';
    return '${(b / 1000).toStringAsFixed(0)} KB';
  }
}

class UpdateService {
  // Public app repo releases (finup-releases was never created; keep CI publishing here).
  static const repo = 'Yashchauhan008/finup';
  static const pageUrl = 'https://github.com/$repo/releases/latest';
  static const shareText =
      'FinUp - my private, offline expense manager. Download the latest APK: $pageUrl';

  static Future<UpdateInfo?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'FinUp');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString();
      final build = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      String? url;
      int? bytes;
      final assets = j['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map) {
            final n = (a['name'] ?? '').toString().toLowerCase();
            if (n.endsWith('.apk')) {
              url = a['browser_download_url']?.toString();
              final s = a['size'];
              if (s is int) bytes = s;
              if (s is num) bytes = s.toInt();
              break;
            }
          }
        }
      }
      if (url == null) return null;
      return UpdateInfo(
        build,
        (j['name'] ?? tag).toString(),
        (j['body'] ?? '').toString(),
        url,
        apkBytes: bytes,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }''',
    already="static const repo = 'Yashchauhan008/finup';",
)

# Update screen: clearer download/install guidance + size
replace_once(
    'lib/screens/update_screen.dart',
    '''      if (info == null) {
        _msg =
            'Could not reach the updates page. Check your internet connection and that the finup-releases repo is set up.';
      }''',
    '''      if (info == null) {
        _msg =
            'Could not reach GitHub releases. Check your internet connection and try again.';
      }''',
    already='Could not reach GitHub releases',
)

replace_once(
    'lib/screens/update_screen.dart',
    '''      _msg = ok
          ? 'Browser opened. Download the APK there, then install it with Android. FinUp never installs APKs itself.'
          : 'Could not open the download page. Try again, or visit GitHub releases manually.';''',
    '''      final size = _info?.sizeLabel;
      _msg = ok
          ? (size == null || size.isEmpty
              ? 'Browser opened. Wait until the APK download finishes completely, then open the file to install. A partial download shows “App not installed”.'
              : 'Browser opened. The APK is about $size — wait until that full size finishes downloading, then install. A partial file shows “App not installed”.')
          : 'Could not open the download page. Try again, or visit GitHub releases manually.';''',
    already='partial download shows',
)

replace_once(
    'lib/screens/update_screen.dart',
    '''                  Text('Build ${_info!.build}',
                      style: TextStyle(color: fin.subtext)),
                  if (_info!.notes.trim().isNotEmpty) ...[''',
    '''                  Text(
                      _info!.sizeLabel.isEmpty
                          ? 'Build ${_info!.build}'
                          : 'Build ${_info!.build} · ${_info!.sizeLabel}',
                      style: TextStyle(color: fin.subtext)),
                  if (_info!.notes.trim().isNotEmpty) ...[''',
    already='sizeLabel.isEmpty',
)

replace_once(
    'lib/screens/update_screen.dart',
    '''            Text(
              'FinUp opens the release in your browser. You download and install the APK there — the app does not install packages itself (safer for Play Protect).',
              textAlign: TextAlign.center,
              style: TextStyle(color: fin.subtext, height: 1.45, fontSize: 13),
            ),''',
    '''            Text(
              'FinUp opens GitHub in your browser. Wait for the full APK download (check the file size), then install. Partial downloads close the installer with “App not installed”. FinUp never installs APKs itself.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fin.subtext, height: 1.45, fontSize: 13),
            ),''',
    already='Partial downloads close the installer',
)

for path, needle, label in [
    ('lib/update/updater.dart', "static const repo = 'Yashchauhan008/finup';", 'updater repo'),
    ('lib/update/updater.dart', 'apkBytes', 'apk size field'),
    ('lib/screens/update_screen.dart', 'Partial downloads close the installer', 'install guidance'),
]:
    if needle not in must(path).read_text():
        raise SystemExit(f'missing {label}')
    print(f'ok {label}')

print('finup11 complete')
PY

echo "FinUp Part 11 (update fix) applied."
