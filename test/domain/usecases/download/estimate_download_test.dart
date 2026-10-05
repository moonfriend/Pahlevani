import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/usecases/download/estimate_download.dart';

const plan = DownloadPlan([
  DownloadFile('https://cdn/a.mp3', DownloadFileKind.audio),
  DownloadFile('https://cdn/b.mp3', DownloadFileKind.audio),
  DownloadFile('https://cdn/v.mp4', DownloadFileKind.followAlongVideo),
  DownloadFile('https://cdn/p.jpg', DownloadFileKind.image),
]);

void main() {
  test('counts only files not on the device yet', () {
    final e = estimateDownload(
      plan: plan,
      alreadyLocal: {'https://cdn/a.mp3'},
      sizes: {
        'https://cdn/a.mp3': 100,
        'https://cdn/b.mp3': 200,
        'https://cdn/v.mp4': 5000,
        'https://cdn/p.jpg': 30,
      },
    );
    expect(e.filesToDownload, 3);
    expect(e.knownBytes, 5230);
    expect(e.filesWithUnknownSize, 0);
    expect(e.isComplete, isFalse);
  });

  test('files with no recorded size are counted separately', () {
    final e = estimateDownload(
      plan: plan,
      alreadyLocal: const {},
      sizes: {'https://cdn/a.mp3': 100},
    );
    expect(e.filesToDownload, 4);
    expect(e.knownBytes, 100);
    expect(e.filesWithUnknownSize, 3);
  });

  test('everything already local → complete, nothing to download', () {
    final e =
        estimateDownload(plan: plan, alreadyLocal: plan.urls, sizes: const {});
    expect(e.isComplete, isTrue);
    expect(e.filesToDownload, 0);
    expect(e.knownBytes, 0);
  });
}
