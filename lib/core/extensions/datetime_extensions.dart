/// Convenience helpers on [DateTime].
extension DateTimeExtensions on DateTime {
  /// True if this date falls on the same calendar day as now.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isPast => isBefore(DateTime.now());

  bool get isFuture => isAfter(DateTime.now());

  /// A short, human-readable relative time string, e.g. "just now",
  /// "5m ago", "3h ago", "2d ago", or a calendar date beyond a week.
  String toRelativeTime() {
    final difference = DateTime.now().difference(this);
    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '$day/$month/$year';
  }
}
