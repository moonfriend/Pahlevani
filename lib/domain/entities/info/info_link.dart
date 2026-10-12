import 'package:equatable/equatable.dart';

/// A page on our website that the app links to from Home. The admin sets the
/// [title] shown on the card and the [url] it opens, so the content can
/// change without an app release.
class InfoLink extends Equatable {
  const InfoLink({required this.title, required this.url});

  final String title;
  final String url;

  @override
  List<Object?> get props => [title, url];
}
