import 'package:flutter/material.dart';

/// Google's own pre-approved "Sign in with Google" button image — see
/// https://developers.google.com/identity/branding-guidelines. Unlike web,
/// Google doesn't technically block a custom button on native platforms,
/// but their guideline still specifies an exact logo, color and padding
/// spec; using their shipped image is what stays compliant with that
/// without us reproducing it (and its proprietary font) by hand.
class GoogleBrandedButton extends StatelessWidget {
  const GoogleBrandedButton({
    required this.onPressed,
    required this.loading,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? 'assets/google_signin/sign_in_with_google_dark.png'
        : 'assets/google_signin/sign_in_with_google_light.png';

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Sign in with Google',
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            // Matches the shipped asset's 180x40 aspect ratio — fixed
            // rather than left to the image's intrinsic size so the tap
            // target is well-defined even before/if the image decodes.
            width: 180,
            height: 40,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Image.asset(asset, width: 180, height: 40),
          ),
        ),
      ),
    );
  }
}
