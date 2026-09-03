import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/navigate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primitives.dart';

/// Travel (§30) — the fork between planning a journey and claiming for one.
///
/// These are two different jobs done at two different times: a tour plan is
/// filed ahead and approved, an expense is claimed afterwards against the
/// travel that actually happened. They used to be separate entries in the menu
/// with nothing saying they were related; putting the choice on one screen
/// makes the pair obvious without merging two workflows that must stay apart.
class TravelHubScreen extends ConsumerWidget {
  const TravelHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Travel')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          _TravelOption(
            icon: Icons.map_outlined,
            title: 'Tour Plan',
            description:
                'Plan the days you will travel, the territory and who you '
                'will call on, then send it for approval.',
            accent: AppColors.brand,
            onTap: () => navigateTo(context, Routes.travelPlans),
          ),
          const SizedBox(height: AppSpacing.md),
          _TravelOption(
            icon: Icons.receipt_long_outlined,
            // "Expenses", not "Travel Expenses". The screen it opens is called
            // Expenses, the side menu calls it Expenses and so does More — the
            // tile was the only place carrying a longer name, and a tile whose
            // label changes on the way through reads as a different screen.
            title: 'Expenses',
            description:
                'Claim fare, food and lodging against the days you travelled, '
                'with bills attached.',
            accent: AppColors.sandDeep,
            onTap: () => navigateTo(context, Routes.expenses),
          ),
        ],
      ),
    );
  }
}

class _TravelOption extends StatelessWidget {
  const _TravelOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconWell(
            icon: icon,
            size: 46,
            glyphSize: 23,
            // Expenses stays amber — the two options are told apart by colour
            // here, where Home's six are told apart by their words.
            color: accent == AppColors.brand ? null : accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMd),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: AppTypography.bodySm.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
