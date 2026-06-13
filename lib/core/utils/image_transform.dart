/// Returns a Supabase Storage image-transform URL for efficient mobile display.
///
/// Supabase's render endpoint resizes/compresses images server-side before
/// delivery, so only the small version is transferred and cached on device.
///
/// Only applies to public-bucket URLs (.../object/public/...). Signed URLs
/// (.../object/sign/...) require Supabase Pro for transforms — for those and
/// all other URLs, the original is returned unchanged.
String supabaseImageTransformUrl(
  String url, {
  int width = 500,
  int height = 500,
  int quality = 80,
  String resize = 'contain',
}) {
  const marker = '/storage/v1/object/public/';
  if (url.isEmpty || !url.contains(marker)) return url;

  final transformed =
      url.replaceFirst(marker, '/storage/v1/render/image/public/');
  final sep = transformed.contains('?') ? '&' : '?';
  return '$transformed${sep}width=$width&height=$height&resize=$resize&quality=$quality';
}
