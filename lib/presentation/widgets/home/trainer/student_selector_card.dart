import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// Trainer's student picker: current student summary + "change" button.
class StudentSelectorCard extends StatelessWidget {
  const StudentSelectorCard({
    super.key,
    required this.student,
    this.onChangeStudent,
  });

  final StudentSummary student;
  final VoidCallback? onChangeStudent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: HomeRadii.card1,
        border: homeBorder(),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE6ECEB),
              border: homeBorder(),
            ),
            padding: const EdgeInsets.all(14),
            child: SvgPicture.asset(
              'assets/icons/home/avatar_placeholder.svg',
              colorFilter:
                  const ColorFilter.mode(Color(0xFFBCC9C7), BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: HomeText.gaegu(size: 21)),
                const SizedBox(height: 4),
                Text(
                  '${student.rank} · ${student.houseLabel} · ${student.progressPercent}%',
                  style: HomeText.patrickHand(
                      size: 13, color: HomeColors.mutedText),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onChangeStudent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: HomeColors.card,
                borderRadius: HomeRadii.small,
                border: homeBorder(),
              ),
              child: Text('change ▾',
                  style: HomeText.patrickHand(
                      size: 12, color: HomeColors.mutedText)),
            ),
          ),
        ],
      ),
    );
  }
}
