import 'package:flutter/material.dart';

/// Static color palette for the app. Referenced by [AppTheme] and directly
/// by widgets that need a status color not exposed via [ColorScheme].
abstract final class AppColors {
  static const primary = Color(0xFF3D5AFE);
  static const primaryDark = Color(0xFF0031CA);
  static const secondary = Color(0xFF00BFA5);

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);

  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);

  static const textPrimary = Color(0xFF1A1C1E);
  static const textSecondary = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);

  // Task status (see docs/SharedTasks_MVP1_PRD.md — Task Status Model)
  static const statusTodo = Color(0xFF9E9E9E);
  static const statusInProgress = Color(0xFFFF9800);
  static const statusDone = Color(0xFF4CAF50);
}
