import 'package:pahlevani/domain/entities/training_session/training_section.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// English display label for a training discipline on the home card.
String trainingSectionLabel(TrainingSection section) => switch (section) {
      TrainingSection.warmUp => 'Warm up',
      TrainingSection.sheno => 'Sheno',
      TrainingSection.mobility => 'Mobility',
      TrainingSection.meel => 'Meel',
      TrainingSection.charkh => 'Charkh',
      TrainingSection.kabbade => 'Kabbade',
      TrainingSection.sang => 'Sang',
      TrainingSection.other => 'Other',
    };

/// Maps a discipline to one of the home's curated section SVGs, where a good
/// match exists. Disciplines without a dedicated icon (mobility, kabbade,
/// other) return null and fall back to a generic glyph on the card.
SectionKey? sectionKeyFor(TrainingSection section) => switch (section) {
      TrainingSection.warmUp => SectionKey.narmesh,
      TrainingSection.sheno => SectionKey.sheno,
      TrainingSection.meel => SectionKey.meel,
      TrainingSection.sang => SectionKey.sang,
      TrainingSection.charkh => SectionKey.pa,
      TrainingSection.mobility => null,
      TrainingSection.kabbade => null,
      TrainingSection.other => null,
    };
