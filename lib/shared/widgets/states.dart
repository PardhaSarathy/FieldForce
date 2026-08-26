import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'buttons.dart';

/// Intentional empty state (§57). Every list in the app uses this — never a
/// blank white screen.
///
/// The [message] should tell the user what would put content here, not merely
/// restate that there is none.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.xxxl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SecondaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                small: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure state with a retry affordance (§59).
///
/// Messages must be human-readable and say what happened to the user's data —
/// "your information is saved locally" is the difference between a rep trusting
/// the app and re-entering a visit by hand.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline,
    this.compact = false,
  });

  const ErrorState.network({
    super.key,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  })  : title = 'No connection',
        message = 'Check your network and try again. '
            'Anything you have entered is saved on this device.',
        icon = Icons.wifi_off_outlined;

  const ErrorState.server({
    super.key,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  })  : title = 'Server unavailable',
        message = 'We could not reach PharmaConnect. This is not your fault — '
            'please try again in a moment.',
        icon = Icons.cloud_off_outlined;

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.xxxl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SecondaryButton(
                label: retryLabel,
                icon: Icons.refresh,
                onPressed: onRetry,
                expand: false,
                small: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Permission request / denial state (§60). Always offers a recovery path;
/// a permanently-denied permission routes the user to system settings.
class PermissionState extends StatelessWidget {
  const PermissionState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.onGrant,
    this.grantLabel = 'Allow access',
    this.onOpenSettings,
    this.isPermanentlyDenied = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onGrant;
  final String grantLabel;
  final VoidCallback? onOpenSettings;
  final bool isPermanentlyDenied;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.warning),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: AppTypography.bodySm, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            if (isPermanentlyDenied)
              PrimaryButton(
                label: 'Open settings',
                onPressed: onOpenSettings,
                expand: false,
              )
            else
              PrimaryButton(
                label: grantLabel,
                onPressed: onGrant,
                expand: false,
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen loading. Prefer [SkeletonList] where the shape of the incoming
/// content is known — a spinner tells the user nothing about what is coming.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: AppTypography.bodySm),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.skeletonBase,
              AppColors.skeletonHighlight,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Skeleton approximating the app's standard card-with-avatar list row, so the
/// transition from loading to loaded does not shift layout (§58).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Skeleton(width: 40, height: 40, radius: AppRadius.pill),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 150, height: 13),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(width: 100, height: 11),
                ],
              ),
            ),
            const Skeleton(width: 56, height: 20, radius: AppRadius.pill),
          ],
        ),
      ),
    );
  }
}

/// Persistent offline notice, shown as a strip under the app bar rather than a
/// transient snackbar — a field user needs to know their connectivity state
/// while they work, not for three seconds (§61).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.pendingCount = 0, this.onTap});

  final int pendingCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningSoft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: AppSizes.iconMd, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pendingCount > 0
                      ? "You're offline · $pendingCount item"
                          "${pendingCount == 1 ? '' : 's'} waiting to sync"
                      : "You're offline · your work is saved on this device",
                  style: AppTypography.caption
                      .copyWith(color: AppColors.warning),
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    size: AppSizes.iconMd, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog used for destructive and irreversible actions.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: AppTypography.body),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: isDestructive
                  ? DangerButton(
                      label: confirmLabel,
                      filled: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  : PrimaryButton(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Full-screen success confirmation used after submitting a workflow (§22).
class SuccessState extends StatelessWidget {
  const SuccessState({
    super.key,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.details,
  });

  final String title;
  final String? message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional summary rows, e.g. the reference number of what was submitted.
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                message!,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (details != null) ...[
            const SizedBox(height: AppSpacing.xl),
            details!,
          ],
          const Spacer(),
          if (primaryLabel != null)
            PrimaryButton(label: primaryLabel!, onPressed: onPrimary),
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(label: secondaryLabel!, onPressed: onSecondary),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
