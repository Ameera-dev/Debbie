import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  const ImageService();

  static const _imageDir = 'transaction_images';
  static const _maxWidth = 1200;
  static const _quality = 80;

  /// Pick an image from [source] and save it as a compressed JPEG.
  /// Returns the relative path (e.g. `transaction_images/abc123.jpg`), or null
  /// if the user cancelled.
  Future<String?> pickAndSave(ImageSource source, String transactionId) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source);
    if (xFile == null) return null;
    return _compressAndSave(File(xFile.path), transactionId);
  }

  Future<String?> _compressAndSave(File file, String transactionId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imageDir));
    if (!await dir.exists()) await dir.create(recursive: true);

    final relativePath = '$_imageDir/$transactionId.jpg';
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

  /// Delete the image file for a given relative path.
  Future<void> delete(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, relativePath));
    if (await file.exists()) await file.delete();
  }

  /// Resolve a relative path to an absolute [File], or null if not found.
  Future<File?> getFile(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, relativePath));
    return (await file.exists()) ? file : null;
  }
}

final imageServiceProvider = Provider<ImageService>(
  (ref) => const ImageService(),
);
