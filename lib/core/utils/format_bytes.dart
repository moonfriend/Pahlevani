/// Human-readable size for download UI (decimal units, like phone storage
/// settings): KB below 1 MB, one decimal under 10 MB, whole MB above,
/// two decimals for GB.
String formatBytes(int bytes) {
  const kb = 1000, mb = 1000 * 1000, gb = 1000 * 1000 * 1000;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= 10 * mb) return '${(bytes / mb).round()} MB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / kb).round()} KB';
}
