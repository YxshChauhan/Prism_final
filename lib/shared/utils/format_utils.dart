/// Utility functions for formatting data
class FormatUtils {
  /// Formats bytes into human-readable string
  /// 
  /// Returns formatted string with appropriate unit (B, KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Formats duration in seconds into human-readable string
  /// 
  /// Returns formatted string with appropriate unit (s, m, h)
  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  /// Formats Duration object into human-readable string
  /// 
  /// Returns formatted string with appropriate unit (s, m, h)
  static String formatDurationFromDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }
}