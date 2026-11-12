import 'package:flutter/material.dart';

/// Brand palette sampled directly from `assets/logo.jpeg`.
///
/// The logo is a JPEG with a baked-in white background and no alpha channel,
/// so it can only ever sit on a white surface. That is why the app ships a
/// light theme only — on a dark surface the asset would render as a white
/// rectangle. Swap in a transparent PNG or SVG and dark mode becomes a small
/// follow-up rather than a rework.
class AppColors {
  /// Deep blue of the "k" mark.
  static const Color brandBlue = Color(0xFF00529E);

  /// Cyan-blue of the "INDIA" wordmark.
  static const Color brandCyan = Color(0xFF009DE0);

  /// Near-black of the "kitagawa" wordmark.
  static const Color ink = Color(0xFF1A181D);

  static const Color surface = Color(0xFFFFFFFF);

  /// Stock in / stock out, used consistently on buttons, chips and reports.
  static const Color inward = Color(0xFF1B7F3B);
  static const Color dispatch = Color(0xFFC0392B);
  static const Color audit = Color(0xFF8E44AD);
}

/// Big-touch-target sizing used throughout the app: this is a warehouse-floor
/// tool, likely operated in a hurry and possibly with gloves on.
class AppSizes {
  static const double primaryButton = 88;
  static const double primaryButtonSpacing = 16;
  static const double minTapTarget = 48;
  static const double listRowHeight = 64;

  static const double quantityFontSize = 56;
  static const double titleFontSize = 22;
  static const double bodyFontSize = 18;
  static const double buttonIconSize = 32;

  /// The logo is a wide 3.8:1 wordmark, so it is always sized by width.
  static const double logoWidthLogin = 260;
  static const double logoWidthSplash = 240;
  static const double logoWidthAppBar = 132;

  static const EdgeInsets screenPadding = EdgeInsets.all(20);
}

class AppAssets {
  static const String logo = 'assets/logo.jpeg';
}

/// Shared text styles.
class AppTextStyles {
  /// The part code is how the floor identifies an item, so it is the headline
  /// of every item row and the name is the subtitle. Wide letter-spacing keeps
  /// codes like `BOLT-01` legible at a glance.
  static const TextStyle partCode = TextStyle(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}
