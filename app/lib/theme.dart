import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const indigo = Color(0xFF2D2A6E);
  static const indigoDeep = Color(0xFF1C1A47);
  static const lavender = Color(0xFF8E8BEA);
  static const pink = Color(0xFFEBB9D6);
  static const ink = Color(0xFF15151C);
  static const income = Color(0xFF34B892);
  static const expense = Color(0xFFE5677F);

  static const List<LinearGradient> cardGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7471E3), Color(0xFFB7A2EA), Color(0xFFF1C6DD)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A36A0), Color(0xFF6F6BDA)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF15151C), Color(0xFF3B3B4D)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE79BC0), Color(0xFFF6D4C2)],
    ),
  ];

  static LinearGradient gradientAt(int i) =>
      cardGradients[i.abs() % cardGradients.length];
}

@immutable
class FinColors extends ThemeExtension<FinColors> {
  final Color bg;
  final Color card;
  final Color text;
  final Color subtext;
  final Color hero;
  final Color divider;

  const FinColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.subtext,
    required this.hero,
    required this.divider,
  });

  static const light = FinColors(
    bg: Color(0xFFEEF0F7),
    card: Colors.white,
    text: AppColors.ink,
    subtext: Color(0xFF8B8BA1),
    hero: AppColors.indigo,
    divider: Color(0xFFE2E3EE),
  );

  static const dark = FinColors(
    bg: Color(0xFF0D0D12),
    card: Color(0xFF1A1A24),
    text: Color(0xFFF2F2F7),
    subtext: Color(0xFF8E8EA6),
    hero: AppColors.indigoDeep,
    divider: Color(0xFF2A2A37),
  );

  @override
  FinColors copyWith({
    Color? bg,
    Color? card,
    Color? text,
    Color? subtext,
    Color? hero,
    Color? divider,
  }) {
    return FinColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      text: text ?? this.text,
      subtext: subtext ?? this.subtext,
      hero: hero ?? this.hero,
      divider: divider ?? this.divider,
    );
  }

  @override
  FinColors lerp(ThemeExtension<FinColors>? other, double t) {
    if (other is! FinColors) return this;
    return FinColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension FinContext on BuildContext {
  FinColors get fin => Theme.of(this).extension<FinColors>() ?? FinColors.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppText {
  static TextStyle display({
    double size = 32,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    try {
      return GoogleFonts.getFont(
        'Unbounded',
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: -0.5,
      );
    } catch (_) {
      return TextStyle(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      );
    }
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final fin = isDark ? FinColors.dark : FinColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lavender,
      brightness: b,
    ).copyWith(
      primary: isDark ? AppColors.lavender : AppColors.indigo,
      onPrimary: Colors.white,
      secondary: AppColors.pink,
      surface: fin.card,
      onSurface: fin.text,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: fin.bg,
    );

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme('DM Sans', base.textTheme);
    } catch (_) {
      textTheme = base.textTheme;
    }

    return base.copyWith(
      textTheme: textTheme.apply(bodyColor: fin.text, displayColor: fin.text),
      extensions: <ThemeExtension<dynamic>>[fin],
      dividerColor: fin.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: fin.bg,
        foregroundColor: fin.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fin.card,
        hintStyle: TextStyle(color: fin.subtext),
        labelStyle: TextStyle(color: fin.subtext),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: fin.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

String inr(double v, {bool hide = false, int decimals = 2}) {
  if (hide) return '₹ • • • •';
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals,
  ).format(v);
}
