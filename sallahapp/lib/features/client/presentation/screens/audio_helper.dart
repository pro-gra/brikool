// Conditionally imports the web or stub implementation.
// On Android/iOS → audio_helper_stub.dart (no dart:html)
// On Web         → audio_helper_web.dart  (dart:html)
export 'audio_helper_stub.dart'
    if (dart.library.html) 'audio_helper_web.dart';