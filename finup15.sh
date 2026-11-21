#!/usr/bin/env bash
# FinUp Part 15 — Clearer "App not installed" guidance (signature / partial download)
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

replace_once(
    'lib/screens/update_screen.dart',
    '''            PrimaryButton(
              label: 'Open download page',
              icon: Icons.open_in_browser_rounded,
              onPressed: _openDownload,
            ),
            const SizedBox(height: 10),
            Text(
              'FinUp opens GitHub in your browser. Wait for the full APK download (check the file size), then install. Partial downloads close the installer with “App not installed”. FinUp never installs APKs itself.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fin.subtext, height: 1.45, fontSize: 13),
            ),
          ],''',
    '''            PrimaryButton(
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
                'If Android says “App not installed” with no reason:\\n'
                '1. In FinUp → Settings → Backup (save the file somewhere safe).\\n'
                '2. Uninstall FinUp completely.\\n'
                '3. Download FinUp.apk again and wait until the file is ~${_info?.sizeLabel.isNotEmpty == true ? _info!.sizeLabel : '39 MB'} (not a tiny HTML file).\\n'
                '4. Install the APK, open FinUp, then Settings → Restore from backup.\\n\\n'
                'Android hides the real cause. Almost always it is either a half-finished download, or the old FinUp was signed with a different key so Android blocks the update.',
                style: TextStyle(color: fin.subtext, height: 1.45, fontSize: 13),
              ),
            ),
          ],''',
    already='If Android says “App not installed”',
)

replace_once(
    'lib/screens/update_screen.dart',
    '''      _msg = ok
          ? (size == null || size.isEmpty
              ? 'Browser opened. Wait until the APK download finishes completely, then open the file to install. A partial download shows “App not installed”.'
              : 'Browser opened. The APK is about $size — wait until that full size finishes downloading, then install. A partial file shows “App not installed”.')
          : 'Could not open the download page. Try again, or visit GitHub releases manually.';''',
    '''      _msg = ok
          ? (size == null || size.isEmpty
              ? 'Browser opened. Wait until FinUp.apk finishes (about 39 MB), then install. If it still says App not installed: Backup → Uninstall FinUp → install the APK → Restore.'
              : 'Browser opened. Wait until FinUp.apk is fully $size, then install. If it still says App not installed: Backup → Uninstall FinUp → install → Restore.')
          : 'Could not open the download page. Try again, or visit GitHub releases manually.';''',
    already='Backup → Uninstall FinUp',
)

checks = [
    ('lib/screens/update_screen.dart', 'If Android says “App not installed”', 'install fail help'),
]
for path, needle, label in checks:
    t = must(path).read_text()
    if needle not in t:
        raise SystemExit(f'verify failed: {label}')
    print(f'ok {label}')
print('finup15 done')
PY
