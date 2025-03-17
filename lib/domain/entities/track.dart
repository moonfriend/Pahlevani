/// Represents an audio track in the application
class Track {
  final int sort;
  final String name;
  final String author;
  final String type;
  final int? nsets;
  final String desc;
  final List<dynamic>? timestamps;
  final double version;
  final String filePath;
  final String imagePath;

  /// Returns the formatted asset path for the audio file
  String get audioAssetPath => 'assets/$filePath';

  /// Returns the formatted asset path for the image
  String get imageAssetPath => 'assets/images/$imagePath';

  const Track({
    required this.sort,
    required this.name,
    required this.author,
    required this.type,
    this.nsets,
    this.desc = '',
    this.timestamps,
    required this.version,
    required this.filePath,
    required this.imagePath,
  });

  /// Creates a Track from JSON data
  factory Track.fromJson(Map<String, dynamic> json) {
    // Format the file path
    String sort = json['sort'].toString().padLeft(2, '0');
    String name = json['name'];
    String filePath = 'audio/$sort $name.mp3';

    // Get image path based on the naming convention
    String imagePath = '${sort}_${name.replaceAll(' ', '_')}.png';

    return Track(
      sort: json['sort'],
      name: json['name'],
      author: json['author'],
      type: json['type'],
      nsets: json['nsets'],
      desc: json['desc'] ?? '',
      timestamps: json['tstamps'],
      version: json['version'].toDouble(),
      filePath: filePath,
      imagePath: imagePath,
    );
  }

  /// Returns a formatted display name by cleaning up the raw name
  String get displayName {
    // Format the display name by removing file extension and replacing underscores
    String displayName = name.replaceAll('_', ' ');

    // Extract the movement name part (remove any numbering)
    if (displayName.contains(' ')) {
      final parts = displayName.split(' ');
      if (parts.length > 1 && parts[0].contains(RegExp(r'\d'))) {
        // If the first part contains numbers, take the rest
        displayName = parts.sublist(1).join(' ');
      }
    }

    // Capitalize first letter of each word
    displayName = displayName.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');

    return displayName;
  }
}
