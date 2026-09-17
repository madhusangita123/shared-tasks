import 'package:flutter/material.dart';

/// Theme-aware color tokens for the app, registered as a [ThemeExtension] on
/// both light and dark [ThemeData] (see [AppTheme]). Retrieve the active set
/// via [AppColors.of] — never reference [light]/[dark] directly from a
/// widget, since that bypasses system dark-mode switching.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerBg,
    required this.dangerBorder,
    required this.border,
    required this.borderStrong,
    required this.statusActivePillBackground,
    required this.statusActivePillText,
  });

  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerBg;
  final Color dangerBorder;
  final Color border;
  final Color borderStrong;

  // Status pill (active state). The pill's border reuses [primary] directly
  // — no separate field needed for that.
  final Color statusActivePillBackground;
  final Color statusActivePillText;

  static const light = AppColors(
    primary: Color(0xFF1D9E75),
    primaryLight: Color(0xFF5DCAA5),
    accent: Color(0xFF0F6E56),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF8FAFB),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    success: Color(0xFF1D9E75),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    dangerBg: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    statusActivePillBackground: Color(0xFFDCF5E7),
    statusActivePillText: Color(0xFF15803D),
  );

  static const dark = AppColors(
    primary: Color(0xFF1D9E75),
    primaryLight: Color(0xFF5DCAA5),
    accent: Color(0xFF5DCAA5),
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF273449),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF475569),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    dangerBg: Color(0xFF450A0A),
    dangerBorder: Color(0xFF7F1D1D),
    border: Color(0xFF1E293B),
    borderStrong: Color(0xFF334155),
    statusActivePillBackground: Color(0xFF14532D),
    statusActivePillText: Color(0xFF86EFAC),
  );

  /// Reads the [AppColors] registered on the current [Theme].
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// Small fixed palette of visually distinct colors used for avatar
  /// backgrounds. Not part of the issue's light/dark token tables — this is
  /// a standalone palette chosen for distinguishing people, and is the same
  /// in light and dark mode.
  static const _avatarPalette = <Color>[
    Color(0xFFEF4444), // red
    Color(0xFFF59E0B), // amber
    Color(0xFF1D9E75), // green
    Color(0xFF0EA5E9), // sky
    Color(0xFF6366F1), // indigo
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
  ];

  /// Deterministic avatar color for [uid] — the same uid always maps to the
  /// same color, from a fixed palette of visually distinct colors.
  static Color avatarSet(String uid) {
    final index = uid.hashCode.abs() % _avatarPalette.length;
    return _avatarPalette[index];
  }

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerBg,
    Color? dangerBorder,
    Color? border,
    Color? borderStrong,
    Color? statusActivePillBackground,
    Color? statusActivePillText,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      statusActivePillBackground:
          statusActivePillBackground ?? this.statusActivePillBackground,
      statusActivePillText: statusActivePillText ?? this.statusActivePillText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      statusActivePillBackground: Color.lerp(
        statusActivePillBackground,
        other.statusActivePillBackground,
        t,
      )!,
      statusActivePillText: Color.lerp(
        statusActivePillText,
        other.statusActivePillText,
        t,
      )!,
    );
  }
}
