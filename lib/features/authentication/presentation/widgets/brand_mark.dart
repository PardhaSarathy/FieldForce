import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The Mr Sales mark.
///
/// Drawn rather than shipped as an asset: it is a simple geometric form (a
/// shield enclosing a connective node) and keeping it as code means it scales
/// crisply and re-colours with the palette. A real brand asset would replace
/// [BrandMarkPainter] without changing any call site.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 48,
    this.showWordmark = true,
    this.showTagline = true,
    this.centered = false,
  });

  final double size;
  final bool showWordmark;
  final bool showTagline;

  /// Centres the mark and wordmark. Used on the login screen, where the brand
  /// is the page's subject rather than a header element.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // The mark is a deep green shield, so by the app's own rule it glows.
        // Ambient rather than tight: this is the one place the brand is the
        // subject of the page rather than a label on it, and a wide soft bloom
        // behind it makes the sign-in screen feel like an entrance. Only where
        // the mark is the subject — the 22px one in a header stays flat, since
        // a glow on a header glyph is just noise beside a title.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: centered
                ? AppGlow.halo(AppColors.brand, size * 1.6)
                : const [],
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: BrandMarkPainter()),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.32),
          Text(
            'Mr Sales',
            style: AppTypography.h2.copyWith(
              fontSize: size * 0.42,
              letterSpacing: -0.4,
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text('Field force. Simplified.', style: AppTypography.bodySm),
        ],
      ],
    );
  }
}

/// The mark on its own, for places that need the glyph without the wordmark —
/// the Home top bar draws it at 22px beside the app name.
class BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield silhouette — trust and protection, without medical clichés.
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.92, h * 0.22)
      ..lineTo(w * 0.92, h * 0.56)
      ..quadraticBezierTo(w * 0.92, h * 0.86, w * 0.5, h * 0.98)
      ..quadraticBezierTo(w * 0.08, h * 0.86, w * 0.08, h * 0.56)
      ..lineTo(w * 0.08, h * 0.22)
      ..close();

    canvas.drawPath(shield, Paint()..color = AppColors.brand);

    // Connective link: two nodes joined by a stem — the "connect" idea.
    final linkPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.36, h * 0.62),
      Offset(w * 0.64, h * 0.38),
      linkPaint,
    );

    canvas.drawCircle(
      Offset(w * 0.34, h * 0.64),
      w * 0.085,
      Paint()..color = AppColors.surface,
    );
    // The accent node is [AppColors.star] rather than [AppColors.sand]: on the
    // blue shield the amber measures 2.86:1 and goes muddy at the 22px the
    // Home bar draws this at, where the brighter yellow holds at 3.72:1.
    canvas.drawCircle(
      Offset(w * 0.66, h * 0.36),
      w * 0.085,
      Paint()..color = AppColors.star,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
