import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

const _assetBySection = {
  SectionKey.narmesh: 'assets/icons/home/section_narmesh.svg',
  SectionKey.sheno: 'assets/icons/home/section_sheno.svg',
  SectionKey.meel: 'assets/icons/home/section_meel.svg',
  SectionKey.sang: 'assets/icons/home/section_sang.svg',
  SectionKey.pa: 'assets/icons/home/section_pa.svg',
};

/// Sketch-style outline icon for a training section, recolorable to match
/// done/active/locked states. Source SVGs are the literal sketch icons from
/// the design handoff (sketch placeholders — README flags these for
/// eventual replacement with a real icon set or commissioned glyphs).
class SectionIcon extends StatelessWidget {
  const SectionIcon({
    super.key,
    required this.section,
    this.color = const Color(0xFF2B2A28),
    this.size = 22,
  });

  final SectionKey section;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetBySection[section]!,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
