import 'package:flutter/material.dart';

/// Theme-aware type scale for the app, registered as a [ThemeExtension] on
/// both light and dark [ThemeData] (see [AppTheme]). Retrieve the active set
/// via [AppTextStyles.of].
///
/// None of these styles set a [TextStyle.color] — color is applied
/// separately via `AppColors` (usually `textPrimary`/`textSecondary`/
/// `textMuted`), per the design system's separation of type scale from
/// color tokens.
///
/// [label] has no built-in "uppercase" transform — [TextStyle] doesn't
/// support one — so callers apply `.toUpperCase()` to the string itself;
/// this style only sets the size/weight/letter-spacing.
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.headingLarge,
    required this.headingMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.caption,
    required this.label,
  });

  final TextStyle headingLarge;
  final TextStyle headingMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle caption;
  final TextStyle label;

  /// Same instance for both light and dark themes — nothing here is
  /// color, so there's nothing to vary by brightness. It's still registered
  /// on both `ThemeData`s to satisfy the "both registering it" requirement.
  static const instance = AppTextStyles(
    headingLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    headingMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    caption: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    label: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.07,
    ),
  );

  /// Reads the [AppTextStyles] registered on the current [Theme].
  static AppTextStyles of(BuildContext context) =>
      Theme.of(context).extension<AppTextStyles>()!;

  @override
  AppTextStyles copyWith({
    TextStyle? headingLarge,
    TextStyle? headingMedium,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? label,
  }) {
    return AppTextStyles(
      headingLarge: headingLarge ?? this.headingLarge,
      headingMedium: headingMedium ?? this.headingMedium,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      caption: caption ?? this.caption,
      label: label ?? this.label,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    // Size/weight/letter-spacing don't have a meaningful "halfway" state the
    // way colors do (there's no light/dark variant of this extension to
    // lerp between in the first place), so this just returns the current
    // instance unchanged.
    return this;
  }
}
