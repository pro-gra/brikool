import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  // ── Limits ────────────────────────────────────────────────────
  static const int _maxImageBytes  = 3 * 1024 * 1024;  // 3MB
  static const int _maxVideoBytes  = 50 * 1024 * 1024; // 50MB
  static const int _maxAudioBytes  = 5 * 1024 * 1024;  // 5MB
  static const int _maxDocBytes    = 3 * 1024 * 1024;  // 3MB

  // ── Allowed MIME types ────────────────────────────────────────
  static const _allowedImageTypes = {'image/jpeg', 'image/png', 'image/webp', 'image/gif'};
  static const _allowedVideoTypes = {'video/mp4', 'video/webm', 'video/quicktime'};
  static const _allowedAudioTypes = {'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg'};
  static const _allowedDocTypes   = {'application/pdf'};

  // ── Validation ────────────────────────────────────────────────

  void _validateFile(Uint8List bytes, String? contentType) {
    if (contentType == null) return;

    final type = contentType.toLowerCase();

    // MIME type check
    final isImage = type.startsWith('image/');
    final isVideo = type.startsWith('video/');
    final isAudio = type.startsWith('audio/');
    final isDoc   = type == 'application/pdf';

    if (isImage && !_allowedImageTypes.contains(type)) {
      throw Exception('Type d\'image non autorisé: $type. Formats acceptés: JPG, PNG, WebP, GIF.');
    }
    if (isVideo && !_allowedVideoTypes.contains(type)) {
      throw Exception('Type de vidéo non autorisé: $type. Formats acceptés: MP4, WebM, MOV.');
    }
    if (isAudio && !_allowedAudioTypes.contains(type)) {
      throw Exception('Type audio non autorisé: $type. Formats acceptés: WebM, MP4, MP3, WAV.');
    }
    if (!isImage && !isVideo && !isAudio && !isDoc) {
      throw Exception('Type de fichier non autorisé: $type.');
    }

    // Size check per type
    if (isImage && bytes.length > _maxImageBytes) {
      final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw Exception('Image trop volumineuse ($mb MB). Maximum: 3 MB.');
    }
    if (isVideo && bytes.length > _maxVideoBytes) {
      final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw Exception('Vidéo trop volumineuse ($mb MB). Maximum: 50 MB.');
    }
    if (isAudio && bytes.length > _maxAudioBytes) {
      final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw Exception('Audio trop volumineux ($mb MB). Maximum: 5 MB.');
    }
    if (isDoc && bytes.length > _maxDocBytes) {
      final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw Exception('Document trop volumineux ($mb MB). Maximum: 3 MB.');
    }
  }

  // ── Compression ───────────────────────────────────────────────

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      return compressed.length < bytes.length ? compressed : bytes;
    } catch (_) {
      return bytes;
    }
  }

  // ── Public upload ─────────────────────────────────────────────

  Future<String> upload({
    required String path,
    required String localPathOrIgnoredOnWeb,
    Uint8List? bytes,
    String? contentType,
  }) {
    return _upload(
      path: path,
      localPathOrIgnoredOnWeb: localPathOrIgnoredOnWeb,
      webBytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> _upload({
    required String path,
    required String localPathOrIgnoredOnWeb,
    Uint8List? webBytes,
    String? contentType,
  }) async {
    final ref = _storage.ref().child(path);
    final metadata = contentType != null ? SettableMetadata(contentType: contentType) : null;
    final isImage = contentType != null && contentType.startsWith('image/');

    if (kIsWeb) {
      var data = webBytes!;
      if (isImage) data = await _compressImage(data);
      _validateFile(data, contentType); // validate AFTER compression
      final task = await ref.putData(data, metadata);
      return task.ref.getDownloadURL();
    } else {
      if (isImage) {
        final raw = await File(localPathOrIgnoredOnWeb).readAsBytes();
        final compressed = await _compressImage(raw);
        _validateFile(compressed, contentType);
        final task = await ref.putData(compressed, metadata);
        return task.ref.getDownloadURL();
      } else {
        final raw = await File(localPathOrIgnoredOnWeb).readAsBytes();
        _validateFile(raw, contentType);
        final task = await ref.putFile(File(localPathOrIgnoredOnWeb), metadata);
        return task.ref.getDownloadURL();
      }
    }
  }

  // ── Convenience methods ───────────────────────────────────────

  Future<String> uploadTechnicianImage({
    required String techId,
    required String fileName,
    required String localPathOrIgnoredOnWeb,
    Uint8List? webBytes,
  }) {
    return _upload(
      path: 'technicians/$techId/$fileName',
      localPathOrIgnoredOnWeb: localPathOrIgnoredOnWeb,
      webBytes: webBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadUserImage({
    required String uid,
    required String fileName,
    required String localPathOrIgnoredOnWeb,
    Uint8List? webBytes,
  }) {
    return _upload(
      path: 'users/$uid/$fileName',
      localPathOrIgnoredOnWeb: localPathOrIgnoredOnWeb,
      webBytes: webBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadChatMedia({
    required String requestId,
    required String senderId,
    required String fileName,
    required String localPathOrIgnoredOnWeb,
    Uint8List? webBytes,
    required bool isVideo,
  }) {
    return _upload(
      path: 'chats/$requestId/${senderId}_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      localPathOrIgnoredOnWeb: localPathOrIgnoredOnWeb,
      webBytes: webBytes,
      contentType: isVideo ? 'video/mp4' : 'image/jpeg',
    );
  }
}