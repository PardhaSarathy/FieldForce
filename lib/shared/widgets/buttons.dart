import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glow.dart';
import 'motion.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Filled brand action. One per screen region — if two primaries compete, one
/// of them is really a secondary.
///
/// [isLoading] replaces the label with a spinner and disables the button, so
/// callers never have to hand-roll a submitting state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final height = small ? AppSizes.buttonHeightSmall : AppSizes.buttonHeight;
    final enabled = onPressed != null && !isLoading;

    // The most-tapped control on any screen, so it is the one that looks
    // pressable: a vertical gradient down the brand family and a *coloured*
    // shadow rather than a grey one. Only three things in the app get a
    // coloured shadow — this, the quick-add button and the active tab — which
    // is what keeps it meaning something.
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.brandLight, AppColors.brand],
              )
            : null,
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: AppColors.brandGlow,
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          gradient: enabled ? AppGlow.sheen : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
            padding: EdgeInsets.symmetric(
              horizontal: small ? AppSpacing.lg : AppSpacing.xl,
            ),
            // The gradient above paints the fill, so the button itself is
            // transparent — with the shadow suppressed, or it would double up.
            backgroundColor: enabled ? Colors.transparent : null,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: const StadiumBorder(),
            textStyle: small
                ? AppTypography.button.copyWith(fontSize: 14)
                : AppTypography.button,
          ),
          child: _ButtonContent(
            label: label,
            icon: icon,
            isLoading: isLoading,
            spinnerColor: AppColors.textOnBrand,
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Bordered action on a white surface. The default for "Back", "Cancel",
/// "Save Draft" and any non-committal choice.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final height = small ? AppSizes.buttonHeightSmall : AppSizes.buttonHeight;
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: small ? AppSpacing.lg : AppSpacing.xl,
        ),
        textStyle: small
            ? AppTypography.button.copyWith(fontSize: 14)
            : AppTypography.button,
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        spinnerColor: AppColors.brand,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Destructive or rejecting action. Reserved for reject, delete, and logout —
/// never used merely for emphasis.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  /// Outlined by default. Fill only for the final confirmation step.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      spinnerColor: filled ? Colors.white : AppColors.error,
    );

    final button = filled
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: expand
                  ? const Size.fromHeight(AppSizes.buttonHeight)
                  : const Size(0, AppSizes.buttonHeight),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: expand
                  ? const Size.fromHeight(AppSizes.buttonHeight)
                  : const Size(0, AppSizes.buttonHeight),
            ),
            child: child,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    required this.spinnerColor,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(spinnerColor),
        ),
      );
    }

    // A button label never wraps. Left to itself it does: in a narrow pair
    // like Details / Start visit the shorter button gets a third of the row,
    // "Details" breaks over two lines, and the whole row grows from 36pt to
    // 48pt — a button silently changing height because of its own text.
    if (icon == null) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textAlign: TextAlign.center,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppSizes.iconMd),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

/// The sticky action bar used at the bottom of forms and detail screens.
/// Sits above the safe area and separates itself from scrolling content with a
/// top border rather than a shadow.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen-level "add" action, and the fourth thing in the app that is lit.
///
/// Material's own extended FAB draws a grey drop shadow, which on a deep green
/// fill reads as dirt under the button rather than as light off it. This is the
/// same fill and the same halo the primary button and the active tab use, so
/// the one control a screen wants you to find looks like it belongs to the
/// same light as everything else — and its glyph blooms, the way every glyph
/// on a dark fill in this app does.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    // Scales in rather than being painted in place: it sits on top of a page
    // that is itself arriving, and a thing landing over settled content is
    // allowed weight. The short delay lets the list underneath move first.
    return PopIn(
      delay: AppMotion.stagger,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: AppGlow.fill(AppColors.brand),
          boxShadow: AppGlow.halo(AppColors.brand, _height),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: AppGlow.sheen,
          ),
          child: FloatingActionButton.extended(
            onPressed: onPressed,
            // The decoration above paints the fill and the light, so the button
            // itself contributes neither — otherwise both shadows stack.
            backgroundColor: Colors.transparent,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            icon: Icon(
              icon,
              size: AppSizes.iconMd,
              color: AppColors.wellGlyph,
              shadows: AppGlow.bloom(AppColors.brand, AppSizes.iconMd),
            ),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppTypography.button.copyWith(color: AppColors.wellGlyph),
            ),
          ),
        ),
      ),
    );
  }
}
