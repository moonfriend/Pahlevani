import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';

/// Equipment a Pahlevani session may require. Only the disciplines that use a
/// tool map to one; the rest (warm up, mobility, charkh, other) need nothing.
enum SessionTool { meel, shenoBoard, kabbade, sang }

const _toolLabels = <SessionTool, String>{
  SessionTool.meel: 'Meel',
  SessionTool.shenoBoard: 'Sheno board',
  SessionTool.kabbade: 'Kabbade',
  SessionTool.sang: 'Sang',
};

/// SVG asset per tool, where one exists. Kabbade has no icon yet — it falls
/// back to a placeholder glyph until a real `section_kabbade.svg` is provided.
const _toolAssets = <SessionTool, String>{
  SessionTool.meel: 'assets/icons/home/section_meel.svg',
  SessionTool.shenoBoard: 'assets/icons/home/section_sheno.svg',
  SessionTool.sang: 'assets/icons/home/section_sang.svg',
};

String toolLabel(SessionTool tool) => _toolLabels[tool]!;

/// The tool a discipline requires, or null if it needs none.
SessionTool? toolForSection(TrainingSection section) => switch (section) {
      TrainingSection.meel => SessionTool.meel,
      TrainingSection.sheno => SessionTool.shenoBoard,
      TrainingSection.kabbade => SessionTool.kabbade,
      TrainingSection.sang => SessionTool.sang,
      _ => null,
    };

/// Distinct tools needed by a set of disciplines, in a stable order.
List<SessionTool> toolsForSections(Iterable<TrainingSection> sections) {
  final needed = <SessionTool>{};
  for (final s in sections) {
    final tool = toolForSection(s);
    if (tool != null) needed.add(tool);
  }
  return SessionTool.values.where(needed.contains).toList();
}

/// A small horizontal strip of tool logos shown on a session card.
class SessionToolsRow extends StatelessWidget {
  const SessionToolsRow({super.key, required this.tools, this.size = 22});

  final List<SessionTool> tools;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final tool in tools)
          Tooltip(
            message: toolLabel(tool),
            child: Container(
              width: size + 12,
              height: size + 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSoft),
              ),
              child: _ToolGlyph(tool: tool, size: size, color: colors.onMuted),
            ),
          ),
      ],
    );
  }
}

class _ToolGlyph extends StatelessWidget {
  const _ToolGlyph(
      {required this.tool, required this.size, required this.color});

  final SessionTool tool;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final asset = _toolAssets[tool];
    if (asset != null) {
      return SvgPicture.asset(asset,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
    }
    // Placeholder for tools without a dedicated SVG (kabbade) — swap later.
    return Icon(Icons.sports_martial_arts, size: size, color: color);
  }
}
