import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImagePickerException implements Exception {
  ImagePickerException(this.message, {this.permissionDenied = false});

  final String message;
  final bool permissionDenied;

  @override
  String toString() => message;
}

class ImageService {
  const ImageService();

  static const _imageDir = 'transaction_images';
  static const _maxWidth = 1200;
  static const _quality = 80;

  /// Pick a single image and save it. [imageId] becomes the filename.
  /// Throws [ImagePickerException] on permission denial or picker failure.
  Future<String?> pickAndSave(ImageSource source, String imageId) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source);
      if (xFile == null) return null;
      return _compressAndSave(File(xFile.path), imageId);
    } on Exception catch (e) {
      throw _mapPickerError(e, source);
    }
  }

  /// Pick multiple images at once. Returns list of saved relative paths.
  /// Throws [ImagePickerException] on permission denial or picker failure.
  Future<List<String>> pickMultipleAndSave(
    ImageSource source,
    String Function() idGenerator,
  ) async {
    final List<XFile> xFiles;
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        xFiles = await picker.pickMultiImage();
      } else {
        // Camera only supports one at a time — fall back to single
        final single = await picker.pickImage(source: source);
        xFiles = single != null ? [single] : [];
      }
    } on Exception catch (e) {
      throw _mapPickerError(e, source);
    }

    final paths = <String>[];
    for (final xFile in xFiles) {
      final imageId = idGenerator();
      final path = await _compressAndSave(File(xFile.path), imageId);
      if (path != null) paths.add(path);
    }
    return paths;
  }

  ImagePickerException _mapPickerError(Exception e, ImageSource source) {
    final raw = e.toString().toLowerCase();
    final isPermission =
        raw.contains('photo_access_denied') ||
        raw.contains('camera_access_denied') ||
        raw.contains('permission');
    if (isPermission) {
      final what = source == ImageSource.camera ? 'camera' : 'photo library';
      return ImagePickerException(
        'Debbie needs $what access. Enable it in Settings to attach photos.',
        permissionDenied: true,
      );
    }
    return ImagePickerException(
      'Could not open the picker. Please try again.',
    );
  }

  Future<String?> _compressAndSave(File file, String imageId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imageDir));
    if (!await dir.exists()) await dir.create(recursive: true);

    final relativePath = '$_imageDir/$imageId.jpg';
    final targetPath = p.join(appDir.path, relativePath);

    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: _maxWidth,
      quality: _quality,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return null;

    await File(targetPath).writeAsBytes(bytes);
    return relativePath;
  }

  /// Delete one image file by its relative path.
  Future<void> delete(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, relativePath));
    if (await file.exists()) await file.delete();
  }

  /// Delete all image files for a list of relative paths.
  Future<void> deleteAll(List<String> paths) async {
    for (final path in paths) {
      await delete(path);
    }
  }

  /// Resolve a relative path to an absolute [File], or null if not found.
  Future<File?> getFile(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, relativePath));
    return (await file.exists()) ? file : null;
  }

  /// Returns total bytes used by all files in the image directory.
  Future<int> totalStorageBytes() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imageDir));
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}

final imageServiceProvider = Provider<ImageService>(
  (ref) => const ImageService(),
);
