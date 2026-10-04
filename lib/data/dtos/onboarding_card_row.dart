import '../../domain/entities/onboarding/onboarding_card.dart';

/// A row of `onboarding_cards` (supabase/migrations/0040). Also the format
/// of the on-device cache.
class OnboardingCardRow {
  OnboardingCardRow({
    required this.position,
    required this.titleEn,
    required this.bodyEn,
    this.imageUrl,
    this.builtinImage,
  });

  final int position;
  final String? titleEn;
  final String bodyEn;
  final String? imageUrl;
  final String? builtinImage;

  factory OnboardingCardRow.fromJson(Map<String, dynamic> m) =>
      OnboardingCardRow(
        position: (m['position'] as num?)?.toInt() ?? 0,
        titleEn: m['title_en'] as String?,
        bodyEn: m['body_en'] as String? ?? '',
        imageUrl: m['image_url'] as String?,
        builtinImage: m['builtin_image'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'title_en': titleEn,
        'body_en': bodyEn,
        'image_url': imageUrl,
        'builtin_image': builtinImage,
      };

  static const _builtins = {
    'figure': BuiltinOnboardingImage.figure,
    'figure_alt': BuiltinOnboardingImage.figureAlt,
    'shamseh': BuiltinOnboardingImage.shamseh,
  };

  /// `null` for a row the app can't show (no title). Unknown built-in names
  /// fall back to the figure; non-https URLs are ignored.
  OnboardingCard? toDomain() {
    final title = titleEn?.trim() ?? '';
    if (title.isEmpty) return null;
    final url = imageUrl?.trim();
    return OnboardingCard(
      title: title,
      body: bodyEn.trim(),
      imageUrl: (url != null && url.startsWith('https://')) ? url : null,
      builtinImage: _builtins[builtinImage] ?? BuiltinOnboardingImage.figure,
    );
  }
}
