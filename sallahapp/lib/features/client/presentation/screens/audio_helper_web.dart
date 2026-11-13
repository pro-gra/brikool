// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class WebRecorderHelper {
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  bool _stopped = false;

  Future<void> start() async {
    _chunks.clear();
    _stopped = false;
    final stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    _recorder = html.MediaRecorder(stream, {'mimeType': 'audio/webm'});
    _recorder!.addEventListener('dataavailable', (event) {
      final blob = (event as html.BlobEvent).data;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    });
    _recorder!.start();
  }

  Future<List<int>?> stop() async {
    if (_recorder == null) return null;
    _stopped = true;
    _recorder!.stop();
    // Wait for dataavailable events to fire
    await Future.delayed(const Duration(milliseconds: 600));
    if (_chunks.isEmpty) return null;
    final blob = html.Blob(_chunks, 'audio/webm');
    final blobUrl = html.Url.createObjectUrl(blob);
    try {
      final response = await http.get(Uri.parse(blobUrl));
      return response.bodyBytes;
    } finally {
      html.Url.revokeObjectUrl(blobUrl);
      _chunks.clear();
      _recorder = null;
    }
  }

  void cancel() {
    _chunks.clear();
    try { _recorder?.stop(); } catch (_) {}
    _recorder = null;
  }
}

class WebPlayerHelper {
  html.AudioElement? _audio;
  bool playing = false;

  void init(String url, {Function()? onEnded}) {
    _audio = html.AudioElement(url)
      ..onEnded.listen((_) {
        playing = false;
        onEnded?.call();
      });
  }

  void play() {
    _audio?.play();
    playing = true;
  }

  void pause() {
    _audio?.pause();
    playing = false;
  }

  int get currentSeconds => _audio?.currentTime.toInt() ?? 0;

  void seek(int seconds) {
    _audio?.currentTime = seconds.toDouble();
  }

  void dispose() {
    _audio?.pause();
    _audio = null;
  }
}