import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
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
        spinnerColor: AppColors.textOnBrand,
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

    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppSizes.iconMd),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
          padding: padding ??
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
