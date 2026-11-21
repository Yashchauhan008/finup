import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  final String note;

  const ComingSoon(
      {super.key, required this.title, required this.icon, required this.note});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [AppColors.lavender, AppColors.pink]),
                ),
                child: Icon(icon, size: 44, color: AppColors.ink),
              ),
              const SizedBox(height: 20),
              Text(title, style: AppText.display(size: 24, color: fin.text)),
              const SizedBox(height: 10),
              Text(note,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fin.subtext, height: 1.5)),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ),
    );
  }
}
