import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0A84FF); // Primary Blue
  static const primaryDark = Color(0xFF0649CC); // Dark Blue
  static const primarySoft = Color(0xFFEAF2FF);
  static const navy = Color(0xFF0A1A33); // Primary Navy
  static const slate = Color(0xFF6B7280); // Text Gray / Slate
  static const muted = Color(0xFF8B98AC);
  static const border = Color(0xFFDCE4EF);
  static const surface = Colors.white;
  static const background = Color(0xFFF8FAFC); // Light Background
  static const success = Color(0xFF22C55E); // Success Green
  static const successSoft = Color(0xFFE9F9EF);
  static const warning = Color(0xFFF59E0B); // Warning Orange
  static const warningYellow = Color(0xFFFACC15); // Warning Yellow
  static const warningSoft = Color(0xFFFFF3DD);
  static const danger = Color(0xFFEF4444); // Danger Red
  static const dangerSoft = Color(0xFFFFECEE);
  static const purple = Color(0xFF6D45E8);
  static const cyan = Color(0xFF00C6FF); // Cyan Accent

  // Dark-mode surface tokens. Keep these alongside the light palette so
  // custom widgets can use the active theme instead of reintroducing white
  // cards or navy text on dark screens.
  static const darkBackground = Color(0xFF07111F);
  static const darkSurface = Color(0xFF111827);
  static const darkElevatedSurface = Color(0xFF172033);
  static const darkBorder = Color(0xFF334155);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundFor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceFor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color elevatedSurfaceFor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color borderFor(BuildContext context) =>
      Theme.of(context).dividerColor;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color primarySoftFor(BuildContext context) =>
      isDark(context) ? primary.withValues(alpha: 0.20) : primarySoft;

  static Color successSoftFor(BuildContext context) =>
      isDark(context) ? success.withValues(alpha: 0.18) : successSoft;

  static Color warningSoftFor(BuildContext context) =>
      isDark(context) ? warning.withValues(alpha: 0.18) : warningSoft;

  static Color dangerSoftFor(BuildContext context) =>
      isDark(context) ? danger.withValues(alpha: 0.18) : dangerSoft;
}
