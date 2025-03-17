# Pahlevani App

A Flutter application for training in Pahlevani, the art of Persian warriors' fitness.

## Features

- Browse through Pahlevani movements with audio guidance
- View images of each movement during practice
- Play along with the movements in sequence
- Navigate between different movements with Previous and Next buttons

## Recent Updates

### Movement Images

The app now displays images of each movement:
- The current movement is shown prominently at the top of the screen
- Each movement in the playlist has a thumbnail image
- The playlist UI has been updated to match the Figma design

## Development Guide

### Adding Movement Images

To add actual images for each movement:

1. Create image files with the same names as specified in `zarb_player_cubit.dart` (in the `imageList` array)
2. Place these files in the `assets/images/` directory
3. Make sure the images are in PNG format
4. The files should be named according to the pattern in the `imageList` (e.g., `01_sheno_01_sarnavazi.png`)

Example:
```
assets/images/
  ├── 00_fath_besmel.png
  ├── 01_sheno_01_sarnavazi.png
  ├── 02_sheno_02_do_shallaghe.png
  └── ...
```

### Placeholder Images

During development, a placeholder is shown when actual images are not available. To generate real placeholder images (instead of the current error fallback), you can:

1. Uncomment the `generatePlaceholderImages` function call in `main.dart`
2. Add code to generate actual images in the `generatePlaceholderImages` function

## Dependencies

- flutter_bloc: State management
- audioplayers: For playing movement audio guides

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
