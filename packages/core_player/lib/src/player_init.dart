import 'package:media_kit/media_kit.dart';

/// Initializes the media backend. Must be called once before any
/// [AtriumPlayerScreen] is shown - do it in `main()` alongside the other
/// bootstrap steps.
///
/// Wrapping `MediaKit.ensureInitialized()` keeps the app layer from depending
/// on media_kit directly.
void initPlayer() {
  MediaKit.ensureInitialized();
}
