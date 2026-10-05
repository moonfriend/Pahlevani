import 'package:pahlevani/data/datasources/media/media_size_remote_datasource.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';

class MediaSizeRepositoryImpl implements MediaSizeRepository {
  /// URLs go into the request's query string (`url=in.(…)`), so a long list
  /// is split to stay well under URL-length limits.
  static const batchSize = 40;

  final MediaSizeRemoteDataSource remote;

  MediaSizeRepositoryImpl({required this.remote});

  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async {
    final all = urls.toList();
    final sizes = <String, int>{};
    for (var i = 0; i < all.length; i += batchSize) {
      final end = i + batchSize < all.length ? i + batchSize : all.length;
      sizes.addAll(await remote.fetchSizes(all.sublist(i, end)));
    }
    return sizes;
  }
}
