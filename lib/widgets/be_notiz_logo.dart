import 'package:flutter/material.dart';

class BENotizLogo extends StatelessWidget {
  final double size;
  final bool showBadge;

  const BENotizLogo({
    super.key,
    this.size = 38,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1976D2), const Color(0xFF0D1B2A)]
              : [const Color(0xFF1565C0), const Color(0xFF0B132B)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF64B5F6).withAlpha(100) : const Color(0xFFBBDEFB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'BE',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontWeight: FontWeight.w900,
                fontSize: size * 0.44,
                color: Colors.white,
                height: 0.95,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'notiz',
              style: TextStyle(
                fontFamily: 'cursive',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.26,
                color: const Color(0xFF90CAF9),
                height: 0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
