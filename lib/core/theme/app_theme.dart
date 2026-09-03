import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Material [ThemeData] from Mr Sales tokens.
///
/// Widgets should read from the theme (or from the token classes directly for
/// non-Material properties). The goal is that a screen file contains layout and
/// content — not color and font decisions.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: AppColors.textOnBrand,
      primaryContainer: AppColors.brandSoft,
      onPrimaryContainer: AppColors.brandDark,
      secondary: AppColors.sand,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: AppColors.sandSoft,
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceSecondary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.error,
      scrim: AppColors.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Transparent: AppBackground paints the ground once, behind the
      // whole navigator. A scaffold colour here would cover it.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      fontFamily: AppTypography.fontFamily,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      dividerTheme: _dividerTheme,
      chipTheme: _chipTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackBarTheme,
      progressIndicatorTheme: _progressTheme,
      switchTheme: _switchTheme,
      checkboxTheme: _checkboxTheme,
      radioTheme: _radioTheme,
      listTileTheme: _listTileTheme,
      tabBarTheme: _tabBarTheme,
      tooltipTheme: _tooltipTheme,
      bottomNavigationBarTheme: _bottomNavTheme,
      floatingActionButtonTheme: _fabTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Status bar / nav bar styling. Applied at the app shell so it survives
  /// route changes.
  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  // ------------------------------------------------------------------------

  static const _textTheme = TextTheme(
    displayLarge: AppTypography.display,
    displayMedium: AppTypography.display,
    headlineLarge: AppTypography.h1,
    headlineMedium: AppTypography.h2,
    headlineSmall: AppTypography.h3,
    titleLarge: AppTypography.h3,
    titleMedium: AppTypography.titleMd,
    titleSmall: AppTypography.titleSm,
    bodyLarge: AppTypography.bodyLg,
    bodyMedium: AppTypography.body,
    bodySmall: AppTypography.bodySm,
    labelLarge: AppTypography.button,
    labelMedium: AppTypography.caption,
    labelSmall: AppTypography.overline,
  );

  // Transparent, so the page's wash runs from the very top of the screen.
  // A white bar over a tinted ground drew a hard horizontal edge under every
  // title — the app looked like two documents stacked, and it was the single
  // biggest thing separating an inner screen from Home, which has always had
  // its ground running edge to edge. The body still starts below the bar, so
  // nothing scrolls underneath and no text loses its background.
  static const _appBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    toolbarHeight: AppSizes.appBarHeight,
    titleTextStyle: AppTypography.h3,
    iconTheme: IconThemeData(color: AppColors.textPrimary, size: AppSizes.iconLg),
    systemOverlayStyle: systemOverlay,
  );

  static const _cardTheme = CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      side: BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
    ),
  );

  static final _inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
    labelStyle: AppTypography.bodySm,
    floatingLabelStyle: AppTypography.bodySm.copyWith(color: AppColors.brand),
    errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
    border: _inputBorder(AppColors.border),
    enabledBorder: _inputBorder(AppColors.border),
    focusedBorder: _inputBorder(AppColors.brand, AppSizes.borderWidthFocus),
    errorBorder: _inputBorder(AppColors.error),
    focusedErrorBorder: _inputBorder(AppColors.error, AppSizes.borderWidthFocus),
    disabledBorder: _inputBorder(AppColors.border),
  );

  static OutlineInputBorder _inputBorder(Color color, [double width = AppSizes.borderWidth]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: AppColors.textOnBrand,
      disabledBackgroundColor: AppColors.surfaceSecondary,
      disabledForegroundColor: AppColors.textSecondary,
      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      elevation: 0,
      textStyle: AppTypography.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );

  static final _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.brand,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      textStyle: AppTypography.button,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );

  static final _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brand,
      textStyle: AppTypography.button,
      minimumSize: const Size(0, AppSizes.buttonHeightSmall),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );

  static const _dividerTheme = DividerThemeData(
    color: AppColors.border,
    thickness: 1,
    space: 1,
  );

  static final _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.brandSoft,
    disabledColor: AppColors.surfaceSecondary,
    labelStyle: AppTypography.bodySm.copyWith(color: AppColors.textPrimary),
    secondaryLabelStyle: AppTypography.bodySm.copyWith(color: AppColors.brandDark),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    side: const BorderSide(color: AppColors.border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    showCheckmark: false,
  );

  static const _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    modalBarrierColor: AppColors.scrim,
    showDragHandle: true,
    dragHandleColor: AppColors.border,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
  );

  static final _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: AppTypography.h3,
    contentTextStyle: AppTypography.body,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );

  static final _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: AppTypography.body.copyWith(color: Colors.white),
    actionTextColor: AppColors.sand,
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  static const _progressTheme = ProgressIndicatorThemeData(
    color: AppColors.brand,
    linearTrackColor: AppColors.surfaceSecondary,
    circularTrackColor: AppColors.surfaceSecondary,
    linearMinHeight: 6,
  );

  static final _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.surface,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.surfaceSecondary,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.border,
    ),
  );

  static final _checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? AppColors.brand : Colors.transparent,
    ),
    checkColor: const WidgetStatePropertyAll(Colors.white),
    side: const BorderSide(color: AppColors.border, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
  );

  static final _radioTheme = RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.border,
    ),
  );

  static const _listTileTheme = ListTileThemeData(
    iconColor: AppColors.textSecondary,
    textColor: AppColors.textPrimary,
    titleTextStyle: AppTypography.titleMd,
    subtitleTextStyle: AppTypography.caption,
    minVerticalPadding: AppSpacing.md,
    horizontalTitleGap: AppSpacing.md,
  );

  static const _tabBarTheme = TabBarThemeData(
    labelColor: AppColors.brand,
    unselectedLabelColor: AppColors.textSecondary,
    labelStyle: AppTypography.titleSm,
    unselectedLabelStyle: AppTypography.body,
    indicatorColor: AppColors.brand,
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: AppColors.border,
  );

  static final _tooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    textStyle: AppTypography.caption.copyWith(color: Colors.white),
  );

  static const _bottomNavTheme = BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.brand,
    unselectedItemColor: AppColors.textSecondary,
    selectedLabelStyle: AppTypography.overline,
    unselectedLabelStyle: AppTypography.overline,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  );

  static final _fabTheme = FloatingActionButtonThemeData(
    backgroundColor: AppColors.brand,
    foregroundColor: AppColors.textOnBrand,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );
}
