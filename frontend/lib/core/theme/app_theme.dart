import 'package:flutter/material.dart';

/// Design tokens — a modernized indigo/violet system (Tailwind-ish scale) replacing the original
/// Figma Make port's flatter Material Indigo. Kept as the single source of truth every screen reads
/// from, so retuning these few values reshapes the whole app's look without touching each screen.
class AppPalette {
  static const primary = Color(0xFF4F46E5); // indigo-600
  static const primaryLight = Color(0xFFEEF2FF); // indigo-50
  static const primaryDark = Color(0xFF4338CA); // indigo-700

  static const sidebarBackground = Color(0xFF181B34);
  static const sidebarBackgroundEnd = Color(0xFF11142B);
  static const sidebarText = Color(0xBFFFFFFF); // rgba(255,255,255,0.75)
  static const sidebarTextActive = Colors.white;
  static const sidebarHover = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const sidebarActive = Color(0x24FFFFFF); // rgba(255,255,255,0.14)

  static const surface = Color(0xFFF7F7FB); // page background
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E7EF);

  static const textPrimary = Color(0xFF15162B);
  static const textSecondary = Color(0xFF5B5D77);
  static const textMuted = Color(0xFF9C9EB3);

  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const successText = Color(0xFF1B5E20);

  static const warning = Color(0xFFB45309);
  static const warningLight = Color(0xFFFEF3C7);
  static const warningText = Color(0xFF92400E);

  static const error = Color(0xFFB91C1C);
  static const errorLight = Color(0xFFFEE2E2);
  static const errorText = Color(0xFF7F1D1D);

  static const draftBg = Color(0xFFF3F4F6);
  static const draftText = Color(0xFF374151);
  static const cancelledBg = Color(0xFFF3F4F6);
  static const cancelledText = Color(0xFF6B7280);
  static const convertedBg = Color(0xFFEDE9FE);
  static const convertedText = Color(0xFF5B21B6);
  static const receivedBg = Color(0xFFDBEAFE);
  static const receivedText = Color(0xFF1D4ED8);
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppPalette.primary,
    brightness: Brightness.light,
    primary: AppPalette.primary,
    surface: AppPalette.card,
    onSurface: AppPalette.textPrimary,
  ),
  scaffoldBackgroundColor: AppPalette.surface,
  fontFamily: 'Inter',
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppPalette.textPrimary,
        displayColor: AppPalette.textPrimary,
      ),
  // Dark, sidebar-matching AppBar (confirmed decision) - the previous white one read as "missing
  // chrome" rather than an actual app bar against this app's light page background.
  appBarTheme: const AppBarTheme(
    backgroundColor: AppPalette.sidebarBackground,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
  ),
  // Matches the dark AppBar above wherever a screen puts a TabBar in its `bottom:` slot.
  tabBarTheme: TabBarThemeData(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white70,
    indicatorColor: Colors.white,
    dividerColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: AppPalette.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shadowColor: Colors.black.withValues(alpha: 0.04),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppPalette.border),
    ),
  ),
  dataTableTheme: DataTableThemeData(
    headingRowColor: WidgetStateProperty.all(AppPalette.primaryLight),
    dataRowMinHeight: 48,
    dataRowMaxHeight: 56,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppPalette.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppPalette.textSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: AppPalette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppPalette.primary,
    foregroundColor: Colors.white,
    shape: const CircleBorder(),
    elevation: 4,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppPalette.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppPalette.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppPalette.primary, width: 1.5)),
    filled: true,
    fillColor: AppPalette.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
  dividerTheme: const DividerThemeData(color: AppPalette.border),
  dialogTheme: DialogThemeData(
    backgroundColor: AppPalette.card,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shadowColor: Colors.black.withValues(alpha: 0.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: const TextStyle(color: AppPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
    contentTextStyle: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppPalette.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppPalette.surface,
    side: const BorderSide(color: AppPalette.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    labelStyle: const TextStyle(fontSize: 12, color: AppPalette.textPrimary),
  ),
);

/// Rounded pill used for every document/item status — colors and shape copied exactly from the
/// Figma source's `StatusChip` component (uppercase, letter-spaced, radius 100).
class StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StatusPill({super.key, required this.label, required this.background, required this.foreground});

  factory StatusPill.draft(String label) => StatusPill(label: label, background: AppPalette.draftBg, foreground: AppPalette.draftText);
  factory StatusPill.info(String label) => StatusPill(label: label, background: AppPalette.primaryLight, foreground: AppPalette.primaryDark);
  factory StatusPill.success(String label) => StatusPill(label: label, background: AppPalette.successLight, foreground: AppPalette.successText);
  factory StatusPill.warning(String label) => StatusPill(label: label, background: AppPalette.warningLight, foreground: AppPalette.warningText);
  factory StatusPill.error(String label) => StatusPill(label: label, background: AppPalette.errorLight, foreground: AppPalette.errorText);
  factory StatusPill.cancelled(String label) => StatusPill(label: label, background: AppPalette.cancelledBg, foreground: AppPalette.cancelledText);
  factory StatusPill.converted(String label) => StatusPill(label: label, background: AppPalette.convertedBg, foreground: AppPalette.convertedText);
  factory StatusPill.link(String label) => StatusPill(label: label, background: AppPalette.receivedBg, foreground: AppPalette.receivedText);

  @override
  Widget build(BuildContext context) {
    // Wrapped in Align so this never stretches to fill its parent's width - it commonly sits
    // inside an Expanded table cell, which otherwise forces it to the full column width instead
    // of hugging the label text.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(100)),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
