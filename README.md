# guess_the_picture

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android Release Hardening

Use this release command so Dart code is obfuscated and symbol files are separated:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Important:
- Keep `build/symbols` private and backed up (do not ship it in the app or commit it).
- Android release builds are also configured with R8/ProGuard minification and resource shrinking.
