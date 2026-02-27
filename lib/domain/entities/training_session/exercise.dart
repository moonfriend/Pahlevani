class Exercise {
  final int id;
  final String name;
  final String? author;
  final String? type;
  final String? audioFileUrl;
  final int repetitionsDefault;
  const Exercise({
    required this.id,
    required this.name,
    this.author,
    this.type,
    this.audioFileUrl,
    this.repetitionsDefault = 1,
  });
}
