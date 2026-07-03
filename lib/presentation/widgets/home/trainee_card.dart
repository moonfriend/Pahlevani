import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// Top card on Trainee Home: avatar, name, rank pill, house subtitle.
class TraineeCard extends StatelessWidget {
  const TraineeCard({super.key, required this.profile});

  final TraineeProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: HomeRadii.card1,
        border: homeBorder(),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFECE6),
              border: homeBorder(),
            ),
            padding: const EdgeInsets.all(16),
            child: SvgPicture.asset(
              'assets/icons/home/avatar_placeholder.svg',
              colorFilter:
                  const ColorFilter.mode(Color(0xFFC9C4BA), BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: HomeText.gaegu(size: 23)),
                const SizedBox(height: 6),
                _RankPill(rank: profile.rank),
                const SizedBox(height: 5),
                Text(
                  '${profile.houseNameFarsi} · ${profile.houseNameEnglish}',
                  style: HomeText.mono(size: 10, color: HomeColors.lightMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});

  final String rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: HomeColors.orangeTint,
        borderRadius: HomeRadii.pill,
        border: homeBorder(color: HomeColors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/home/star.svg',
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(
                HomeColors.orangeTextDeep, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          Text(rank,
              style: HomeText.patrickHand(
                  size: 13, color: HomeColors.orangeTextDeep)),
        ],
      ),
    );
  }
}
