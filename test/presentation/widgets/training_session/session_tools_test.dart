import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_tools.dart';

void main() {
  group('toolForSection', () {
    test('maps the tool-bearing disciplines', () {
      expect(toolForSection(TrainingSection.meel), SessionTool.meel);
      expect(toolForSection(TrainingSection.sheno), SessionTool.shenoBoard);
      expect(toolForSection(TrainingSection.kabbade), SessionTool.kabbade);
      expect(toolForSection(TrainingSection.sang), SessionTool.sang);
    });

    test('disciplines without a tool map to null', () {
      expect(toolForSection(TrainingSection.warmUp), isNull);
      expect(toolForSection(TrainingSection.mobility), isNull);
      expect(toolForSection(TrainingSection.charkh), isNull);
      expect(toolForSection(TrainingSection.other), isNull);
    });
  });

  group('toolsForSections', () {
    test('collects distinct tools in a stable order', () {
      final tools = toolsForSections([
        TrainingSection.sang,
        TrainingSection.meel,
        TrainingSection.meel, // duplicate
        TrainingSection.warmUp, // no tool
      ]);
      expect(tools, [SessionTool.meel, SessionTool.sang]);
    });

    test('a session with no tool-bearing disciplines needs nothing', () {
      expect(
        toolsForSections([TrainingSection.warmUp, TrainingSection.mobility]),
        isEmpty,
      );
    });

    test('every tool has a label', () {
      for (final tool in SessionTool.values) {
        expect(toolLabel(tool), isNotEmpty);
      }
    });
  });
}
