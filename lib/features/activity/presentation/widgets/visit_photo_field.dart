import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/primitives.dart';

/// A photo taken at the client, under the geo-fence panel.
///
/// The two together are what a visit is evidenced by: the fence says the rep
/// was *near* the clinic, the photo says they were *in* it with the client. A
/// position on its own is the easier half to produce without being there.
///
/// Sits on the Location step deliberately — it belongs with the other proof of
/// presence, and it has to be taken while the rep is standing there, which is
/// exactly when that step is on screen.
///
/// Thumbnails are **rounded squares, not circles**: they stand in for
/// photographs, and photographs are not round. That is the one documented
/// exception to the app's circle rule.
class VisitPhotoField extends StatelessWidget {
  const VisitPhotoField({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
    this.note,
  });

  final List<String> photos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final bool enabled;

  /// Shown in place of the prompt when the control is read-only.
  final String? note;

  static const _tile = 72.0;

  @override
  Widget build(BuildContext context) {
    final empty = photos.isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: AppSizes.iconMd,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Photo with client', style: AppTypography.titleSm),
              ),
              Text(
                note != null
                    ? ''
                    : empty
                    ? 'Optional'
                    : Fmt.count(photos.length, 'photo'),
                style: AppTypography.caption,
              ),
            ],
          ),

          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note!, style: AppTypography.caption.copyWith(height: 1.35)),
          ],

          const SizedBox(height: AppSpacing.md),

          // Empty, it is a button — the same control the expense form uses to
          // ask for a bill, so the app has one way of saying "photograph
          // something". It was a lone dashed square sitting under a paragraph,
          // which read as a gap in the layout rather than as an invitation.
          if (empty && enabled)
            SecondaryButton(
              label: 'Take photo',
              icon: Icons.photo_camera_outlined,
              small: true,
              onPressed: () {
                AppHaptics.selection();
                onAdd();
              },
            )
          else if (!empty)
            SizedBox(
              height: _tile,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final photo in photos)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _PhotoTile(
                        name: photo,
                        onRemove: enabled ? () => onRemove(photo) : null,
                      ),
                    ),
                  // The add tile trails the photos once there are some: it is
                  // "one more", not the whole prompt.
                  if (enabled) _AddTile(onTap: onAdd),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: VisitPhotoField._tile,
        height: VisitPhotoField._tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          size: AppSizes.iconMd,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.name, required this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: VisitPhotoField._tile,
      height: VisitPhotoField._tile,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: VisitPhotoField._tile,
            height: VisitPhotoField._tile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.close, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
