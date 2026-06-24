import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';

/// Fixed bottom tab bar: Home / Plan / Progress / Profile. Only Home is
/// real today — the other tabs are visual placeholders pending Track 1's
/// page-routing decision.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    this.activeIndex = 0,
    this.activeColor = HomeColors.orange,
  });

  final int activeIndex;
  final Color activeColor;

  static const _icons = [
    'assets/icons/home/nav_home.svg',
    'assets/icons/home/nav_plan.svg',
    'assets/icons/home/star.svg',
    'assets/icons/home/nav_profile.svg',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        color: HomeColors.traineeSurface,
        border: Border(top: BorderSide(color: HomeColors.ink, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_icons.length, (i) {
          final active = i == activeIndex;
          return SvgPicture.asset(
            _icons[i],
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              active ? activeColor : HomeColors.hairline,
              BlendMode.srcIn,
            ),
          );
        }),
      ),
    );
  }
}
