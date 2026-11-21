import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../screens/update_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class UpdateInfo {
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
  }

  static Future<void> autoCheck(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('lastUpdateCheck') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < const Duration(hours: 20).inMilliseconds) return;
    await prefs.setInt('lastUpdateCheck', now);
    final info = await latest();
    if (info == null) return;
    final (_, cur) = await Native.appInfo();
    if (info.build <= cur || !context.mounted) return;
    final fin = context.fin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const FinUpLogo(size: 60),
            const SizedBox(height: 14),
            Text('Update available', style: AppText.display(size: 20, color: fin.text)),
            const SizedBox(height: 6),
            Text('${info.name} is ready. Your data stays safe.',
                textAlign: TextAlign.center, style: TextStyle(color: fin.subtext)),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Update now',
              icon: Icons.system_update_rounded,
              onPressed: () {
                Navigator.pop(c);
                Navigator.of(context).push(fadeRoute(const UpdateScreen()));
              },
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
          ]),
        ),
      ),
    );
  }
}
