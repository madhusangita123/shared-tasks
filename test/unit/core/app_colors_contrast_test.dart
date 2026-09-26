// WCAG contrast guards for the theme's text-on-surface pairings.
//
// These exist because a token can drift to an unreadable value while every
// other test still passes: the rest of the suite only asserts that tokens
// exist and resolve per mode, never that the result can actually be read.
// Dark `textMuted` shipped at 1.66:1 against the detail sheet — the section
// labels were close to invisible — and nothing failed.
//
// The thresholds below are what the palette genuinely achieves today, with
// only enough headroom to catch a regression. They are deliberately NOT all
// set to WCAG AA: several pairings don't meet it (see the group comments),
// and asserting a level the palette doesn't reach would just mean a test
// that has to be skipped or weakened later.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';

/// Relative luminance per WCAG 2.x. Not a plain RGB average — each channel is
/// linearised out of sRGB's gamma curve first, then weighted by how much the
/// eye actually responds to it (green dominates, blue barely registers).
double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between two opaque colours: 1.0 (identical) to 21.0
/// (black on white).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Every surface body text can sit on, so a pairing is checked against its
/// worst case rather than its most flattering one.
List<(String, Color)> _surfaces(AppColors c) => [
  ('background', c.background),
  ('surface', c.surface),
  ('surfaceElevated', c.surfaceElevated),
];

void expectMinContrast(
  Color foreground,
  Color background, {
  required double atLeast,
  required String because,
}) {
  final ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(atLeast),
    reason:
        '$because — got ${ratio.toStringAsFixed(2)}:1, '
        'needs at least ${atLeast.toStringAsFixed(1)}:1',
  );
}

void main() {
  for (final (mode, colors) in <(String, AppColors)>[
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    group('AppColors.$mode — text contrast', () {
      test('textPrimary clears AAA on every surface', () {
        for (final (name, surface) in _surfaces(colors)) {
          expectMinContrast(
            colors.textPrimary,
            surface,
            atLeast: 7,
            because: 'textPrimary on $name is the app\'s main body text',
          );
        }
      });

      test('textSecondary clears AA on every surface', () {
        // Section labels (STATUS / ASSIGN TO / MEMBERS / ...) use this. They
        // are structural — you navigate by them — so they hold the full AA
        // 4.5:1 bar for normal text. Light mode currently sits at 4.55:1, so
        // this has little slack by design: darkening it would fail here.
        for (final (name, surface) in _surfaces(colors)) {
          expectMinContrast(
            colors.textSecondary,
            surface,
            atLeast: 4.5,
            because: 'textSecondary on $name carries the section labels',
          );
        }
      });

      test('textMuted stays clear of unreadable on every surface', () {
        // 3.0:1, not 4.5:1, and that gap is deliberate. textMuted is the
        // dimmest tier (placeholders, the add-row "+" ring, unassigned
        // icons, done-task strikethrough). Pushing it to full AA would make
        // it indistinguishable from textSecondary, collapsing three text
        // tiers into two — the palette has no room for both on
        // surfaceElevated. 3.0:1 is WCAG's large-text/non-text floor and is
        // far above the 1.66:1 that made these invisible in dark mode.
        for (final (name, surface) in _surfaces(colors)) {
          expectMinContrast(
            colors.textMuted,
            surface,
            atLeast: 3,
            because: 'textMuted on $name carries placeholders and hints',
          );
        }
      });

      test('the active status pill is readable against its own background', () {
        expectMinContrast(
          colors.statusActivePillText,
          colors.statusActivePillBackground,
          atLeast: 4,
          because: 'the selected status pill is the sheet\'s primary signal',
        );
      });

      test('danger text is readable on dangerBg', () {
        expectMinContrast(
          colors.danger,
          colors.dangerBg,
          atLeast: 3,
          because: 'the Delete task button uses danger on dangerBg',
        );
      });
    });
  }

  group('AppColors — known sub-AA pairings', () {
    // Recorded rather than asserted away. Both involve the brand green, so
    // raising them is a brand decision, not a tuning one. These tests pin
    // the current values so that a change to `primary` surfaces here as a
    // deliberate choice instead of passing unnoticed.
    test('white on primary is legible but below AA for normal text', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final ratio = contrastRatio(const Color(0xFFFFFFFF), colors.primary);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason: 'primary buttons put white text on primary',
        );
        expect(
          ratio,
          lessThan(4.5),
          reason:
              'If primary has been changed so this now clears AA, that is an '
              'improvement — delete this expectation rather than working '
              'around it.',
        );
      }
    });

    test('primary as link text clears AA only in dark mode', () {
      // The "Home"/"Cancel" back links. Dark is comfortable; light is not,
      // because the same green sits on white.
      expectMinContrast(
        AppColors.dark.primary,
        AppColors.dark.background,
        atLeast: 4.5,
        because: 'back links use primary on background',
      );
      expect(
        contrastRatio(AppColors.light.primary, AppColors.light.background),
        lessThan(4.5),
        reason:
            'Light-mode primary-on-white is 3.39:1. Documented, not endorsed '
            '— if primary is darkened this becomes a passing case and this '
            'expectation should go.',
      );
    });
  });

  group('contrastRatio', () {
    test('returns 21 for black on white and 1 for a colour on itself', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFF475569), const Color(0xFF475569)),
        closeTo(1, 0.001),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF1D9E75);
      const b = Color(0xFF0F172A);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 0.0001));
    });

    test('reproduces the regression this suite exists for', () {
      // The exact pairing that shipped: old dark textMuted on the detail
      // sheet. If someone reintroduces it, the textMuted test above fails —
      // this pins the number that made it unreadable.
      expect(
        contrastRatio(const Color(0xFF475569), const Color(0xFF273449)),
        closeTo(1.66, 0.01),
      );
    });
  });
}
