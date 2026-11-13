// Stub — used on Android/iOS. Real web impl is audio_helper_web.dart.
class WebRecorderHelper {
  Future<void> start() async {}
  Future<List<int>?> stop() async => null;
  void cancel() {}
}

class WebPlayerHelper {
  void init(String url, {Function()? onEnded}) {}
  void play() {}
  void pause() {}
  int get currentSeconds => 0;
  void seek(int seconds) {}
  void dispose() {}
}