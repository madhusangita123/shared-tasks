/// Convenience helpers on non-nullable [String].
extension StringExtensions on String {
  /// True if the string is empty once leading/trailing whitespace is removed.
  bool get isBlank => trim().isEmpty;

  /// True if the string has non-whitespace content.
  bool get isNotBlank => !isBlank;

  /// Upper-cases the first character, leaving the rest unchanged.
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Truncates to [maxLength] characters, appending an ellipsis if cut.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }
}

/// Convenience helpers on nullable [String].
extension NullableStringExtensions on String? {
  /// True if this is null, empty, or whitespace-only.
  bool get isNullOrBlank {
    final value = this;
    return value == null || value.trim().isEmpty;
  }
}
