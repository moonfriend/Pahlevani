import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// "Progress in the first house" card: percent label, pill progress bar,
/// and a milestone row from current rank to the next house.
class HouseProgressCard extends StatelessWidget {
  const HouseProgressCard({super.key, required this.profile});

  final TraineeProfile profile;

  @override
  Widget build(BuildContext context) {
    final percent = profile.houseProgressPercent.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: HomeRadii.card2,
        border: homeBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress in the first house',
                  style: HomeText.patrickHand(size: 15)),
              Text('$percent%',
                  style: HomeText.mono(
                      size: 12, color: HomeColors.orangeTextDeep)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: HomeRadii.pill,
            child: Container(
              height: 13,
              decoration: BoxDecoration(
                color: HomeColors.traineeSurface,
                borderRadius: HomeRadii.pill,
                border: homeBorder(),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent / 100,
                child: Container(color: HomeColors.orange),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomeColors.orange,
                  border: homeBorder(),
                ),
              ),
              const SizedBox(width: 5),
              Text(profile.rank,
                  style: HomeText.patrickHand(
                      size: 12, color: HomeColors.mutedText)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CustomPaint(
                    size: const Size(double.infinity, 2),
                    painter: _DashedLinePainter(color: HomeColors.hairlineSoft),
                  ),
                ),
              ),
              Text(profile.nextHouseName,
                  style: HomeText.patrickHand(
                      size: 12, color: HomeColors.lightMuted2)),
              const SizedBox(width: 5),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HomeColors.hairline, width: 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, size.height / 2), Offset(x + 4, size.height / 2), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
