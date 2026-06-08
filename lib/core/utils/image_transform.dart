/// Returns a Supabase Storage image-transform URL for efficient mobile display.
///
/// Supabase's render endpoint resizes/compresses images server-side before
/// delivery, so only the small version is transferred and cached on device.
///
/// For non-Supabase URLs (CDNs, signed URLs, local paths) the original is
/// returned unchanged so callers never need to guard the result.
String supabaseImageTransformUrl(
  String url, {
  int width = 500,
  int height = 500,
  int quality = 80,
  String resize = 'contain',
}) {
  const marker = '/storage/v1/object/public/';
  if (url.isEmpty || !url.contains(marker)) return url;

  final transformed = url.replaceFirst(marker, '/storage/v1/render/image/public/');
  final sep = transformed.contains('?') ? '&' : '?';
  return '${transformed}${sep}width=$width&height=$height&resize=$resize&quality=$quality';
}
