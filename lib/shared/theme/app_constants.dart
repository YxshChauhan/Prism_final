import 'package:flutter/material.dart';

/// App-wide constants for spacing, colors, and text styles
class AppUiConstants {
  // Color constants
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color surfaceColor = Color(0xFFFEF7FF);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  
  // Spacing constants
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Shape constants
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  
  // Text style constants
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}

/// Alias for backward compatibility
typedef AppTheme = AppUiConstants;

