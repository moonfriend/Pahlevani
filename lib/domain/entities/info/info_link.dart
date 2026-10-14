import 'package:equatable/equatable.dart';

/// A page on our website that the app links to from Home. The admin sets the
/// [title] shown on the card and the [url] it opens, so the content can
/// change without an app release.
class InfoLink extends Equatable {
  const InfoLink(
      {required this.title, required this.url, this.description = ''});

  final String title;

  /// A line under the title, e.g. "Make your own, order, or pre-order."
  final String description;
  final String url;

  /// Identifies this version of the card: any change to what the user sees
  /// or where it leads makes it new again.
  String get contentKey => '$title\n$description\n$url';

  @override
  List<Object?> get props => [title, description, url];
}
