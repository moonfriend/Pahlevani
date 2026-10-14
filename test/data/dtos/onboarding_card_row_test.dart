import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/onboarding_card_row.dart';
import 'package:pahlevani/domain/entities/onboarding/onboarding_card.dart';

void main() {
  final row = {
    'id': 4,
    'position': 2,
    'title_en': '  Count what matters ',
    'body_en': 'Log your reps.',
    'title_fa': 'آنچه مهم است را بشمار',
    'body_fa': null,
    'image_url': 'https://pub.r2.dev/images/onboarding/a.webp',
    'builtin_image': 'figure_alt',
    'is_active': true,
  };

  test('maps a Supabase row to a card', () {
    final card = OnboardingCardRow.fromJson(row).toDomain()!;
    expect(card.title, 'Count what matters');
    expect(card.body, 'Log your reps.');
    expect(card.imageUrl, 'https://pub.r2.dev/images/onboarding/a.webp');
    expect(card.builtinImage, BuiltinOnboardingImage.figureAlt);
  });

  test('an unknown built-in picture falls back to the figure', () {
    final card = OnboardingCardRow.fromJson({...row, 'builtin_image': 'sunset'})
        .toDomain()!;
    expect(card.builtinImage, BuiltinOnboardingImage.figure);
  });

  test('a card without a title is dropped', () {
    expect(OnboardingCardRow.fromJson({...row, 'title_en': '  '}).toDomain(),
        isNull);
    expect(OnboardingCardRow.fromJson({...row, 'title_en': null}).toDomain(),
        isNull);
  });

  test('only https image URLs are used', () {
    final card = OnboardingCardRow.fromJson(
        {...row, 'image_url': 'http://example.com/a.png'}).toDomain()!;
    expect(card.imageUrl, isNull);
  });

  test('survives a JSON round trip (the local cache)', () {
    final original = OnboardingCardRow.fromJson(row);
    final copy = OnboardingCardRow.fromJson(original.toJson());
    expect(copy.toDomain(), original.toDomain());
  });

  test('link buttons: up to three, https only, labelled; cached with the card',
      () {
    final r = OnboardingCardRow.fromJson({
      ...row,
      'links': [
        {'label': 'Make your own', 'url': 'https://rahaavi.com/meel/diy'},
        {'label': 'Order', 'url': 'https://rahaavi.com/meel/order'},
        {'label': 'Bad', 'url': 'http://example.com'},
        {'label': '', 'url': 'https://example.com'},
        {'label': 'Pre-order', 'url': 'https://rahaavi.com/meel/pre'},
        {'label': 'Fourth', 'url': 'https://example.com/4'},
      ],
    });
    final card = r.toDomain()!;
    expect(card.links.map((l) => l.label),
        ['Make your own', 'Order', 'Pre-order']);
    expect(OnboardingCardRow.fromJson(r.toJson()).toDomain(), card);
  });

  test('no links column (before migration 0046): no buttons', () {
    expect(OnboardingCardRow.fromJson(row).toDomain()!.links, isEmpty);
  });
}
