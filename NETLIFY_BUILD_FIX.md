# Netlify build fix

This package expects the installed Netlify plugin `netlify-plugin-flutter` to provide the Flutter SDK.
The `netlify.toml` intentionally does not clone Flutter a second time.

Build steps:

1. Flutter SDK is installed by `netlify-plugin-flutter`.
2. `flutter pub get`
3. `flutter build web --release --no-wasm-dry-run`
4. Netlify publishes `build/web`.

If the Flutter plugin is removed in Netlify, the build command must be changed accordingly.
