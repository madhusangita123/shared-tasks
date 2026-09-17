/// App-wide border radius scale. Use these constants everywhere instead of
/// hardcoding magic numbers for `BorderRadius.circular`.
abstract final class AppRadius {
  static const double radiusSm = 8; // buttons, chips
  static const double radiusMd = 12; // cards
  static const double radiusLg = 16; // bottom sheets, large cards
  static const double radiusFull = 99; // pills, avatars
}
