import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database/database_helper.dart';
import '../data/database/tables.dart';
import '../data/database/tag_rename.dart';
import '../providers/database_provider.dart';
import 'google_oauth_config.dart';

// ---------------------------------------------------------------------------
// Authenticated HTTP client for Google APIs
// ---------------------------------------------------------------------------

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

// ---------------------------------------------------------------------------
// Backup metadata
// ---------------------------------------------------------------------------

class BackupInfo {
  const BackupInfo({
    required this.id,
    required this.name,
    required this.createdTime,
    this.size,
  });

  final String id;
  final String name;
  final DateTime createdTime;
  final int? size;
}

class GoogleDriveAuthException implements Exception {
  GoogleDriveAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Google Drive Service
// ---------------------------------------------------------------------------

class GoogleDriveService {
  GoogleDriveService(this._dbHelper);

  final DatabaseHelper _dbHelper;

  static const _folderName = 'Debbie Backups';
  static const _imageDir = 'transaction_images';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: GoogleOAuthConfig.iosClientId,
    serverClientId: GoogleOAuthConfig.serverClientId,
    scopes: [drive.DriveApi.driveFileScope],
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> signIn() async {
    _assertPlatformSetup();
    try {
      return await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  bool get isSignedIn => _googleSignIn.currentUser != null;

  Future<drive.DriveApi?> _getDriveApi() async {
    _assertPlatformSetup();
    try {
      final account =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (account == null) return null;
      final authHeaders = await account.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      return drive.DriveApi(client);
    } on PlatformException catch (e) {
      throw _mapAuthError(e);
    }
  }

  void _assertPlatformSetup() {
    if (GoogleOAuthConfig.requiresIosClientId &&
        GoogleOAuthConfig.iosClientId == null) {
      throw GoogleDriveAuthException(
        'Google Sign-In is not configured for iOS. Add GOOGLE_IOS_CLIENT_ID and the matching URL scheme before using backup.',
      );
    }
  }

  GoogleDriveAuthException _mapAuthError(PlatformException e) {
    final raw = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

    if (defaultTargetPlatform == TargetPlatform.android &&
        e.code == GoogleSignIn.kSignInFailedError &&
        raw.contains('apiexception: 10')) {
      return GoogleDriveAuthException(
        'Google Sign-In OAuth is misconfigured for Android. Register package '
        '${GoogleOAuthConfig.androidPackageName} with the SHA-1 of the signing key '
        'you are using, enable Google Drive API, and provide '
        'GOOGLE_SERVER_CLIENT_ID when running the app.',
        code: e.code,
      );
    }

    if (e.code == GoogleSignIn.kNetworkError) {
      return GoogleDriveAuthException(
        'Google Sign-In could not reach Google. Check the network connection and try again.',
        code: e.code,
      );
    }

    if (e.code == GoogleSignIn.kSignInRequiredError) {
      return GoogleDriveAuthException(
        'Please sign in to Google before using backup or restore.',
        code: e.code,
      );
    }

    final message = e.message?.trim();
    if (message != null && message.isNotEmpty) {
      return GoogleDriveAuthException(message, code: e.code);
    }

    return GoogleDriveAuthException(
      'Google Sign-In failed with code ${e.code}.',
      code: e.code,
    );
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  Future<void> backup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Not signed in');

    // 1. Export all tables to JSON
    final jsonData = await _exportAllTables();

    // 2. Create ZIP archive
    final zipBytes = await _createZipArchive(jsonData);

    // 3. Find or create the Debbie Backups folder
    final folderId = await _getOrCreateFolder(driveApi);

    // 4. Upload ZIP to Google Drive
    final now = DateTime.now();
    final fileName =
        'debbie-backup-${now.year}-${_pad(now.month)}-${_pad(now.day)}.zip';

    final media = drive.Media(Stream.value(zipBytes), zipBytes.length);

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId]
      ..mimeType = 'application/zip';

    await driveApi.files.create(driveFile, uploadMedia: media);
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  Future<List<BackupInfo>> listBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Not signed in');

    final folderId = await _findFolder(driveApi);
    if (folderId == null) return [];

    final result = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,createdTime,size)',
    );

    return (result.files ?? []).map((f) {
      return BackupInfo(
        id: f.id!,
        name: f.name ?? 'Unknown',
        createdTime: f.createdTime ?? DateTime.now(),
        size: f.size != null ? int.tryParse(f.size!) : null,
      );
    }).toList();
  }

  Future<void> restore(String fileId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Not signed in');

    // 1. Download the ZIP
    final media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    // 2. Extract ZIP
    final archive = ZipDecoder().decodeBytes(bytes);

    // 3. Find data.json in the archive
    final dataEntry = archive.files.firstWhere(
      (f) => f.name == 'data.json',
      orElse: () => throw Exception('Invalid backup: missing data.json'),
    );

    final jsonStr = utf8.decode(dataEntry.content as List<int>);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 4. Clear local database and import
    await _importAllTables(data);

    // 5. Extract images to local directory
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, _imageDir));
    if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
    await imageDir.create(recursive: true);

    for (final file in archive.files) {
      if (file.name.startsWith('images/') && !file.isFile) continue;
      if (!file.name.startsWith('images/') || !file.isFile) continue;

      final fileName = p.basename(file.name);
      final outFile = File(p.join(imageDir.path, fileName));
      await outFile.writeAsBytes(file.content as List<int>);
    }
  }

  // ── Storage info ──────────────────────────────────────────────────────────

  Future<int> getLocalImageStorageBytes() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, _imageDir));
    if (!await imageDir.exists()) return 0;

    int total = 0;
    await for (final entity in imageDir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _exportAllTables() async {
    final db = await _dbHelper.database;

    final data = <String, dynamic>{};
    for (final table in Tables.backupTables) {
      final rows = await db.query(table);
      data[table] = rows;
    }
    data['_version'] = DatabaseHelper.dbVersion;
    data['_exportedAt'] = DateTime.now().toIso8601String();

    return data;
  }

  Future<List<int>> _createZipArchive(Map<String, dynamic> jsonData) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    // Add data.json
    final jsonBytes = utf8.encode(jsonEncode(jsonData));
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // Add images
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, _imageDir));
    if (await imageDir.exists()) {
      await for (final entity in imageDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final name = 'images/${p.basename(entity.path)}';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
    }

    return encoder.encode(archive)!;
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi) async {
    final existing = await _findFolder(driveApi);
    if (existing != null) return existing;

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id!;
  }

  Future<String?> _findFolder(drive.DriveApi driveApi) async {
    final result = await driveApi.files.list(
      q: "name = '$_folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  Future<void> _importAllTables(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;

    // Order matters: disable FK, clear all, insert in dependency order, re-enable
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        // Clear all tables
        for (final table in Tables.restoreDeleteOrder) {
          await txn.delete(table);
        }

        // Insert in dependency order
        for (final table in Tables.restoreInsertOrder) {
          final rows = data[table];
          if (rows == null) continue;
          for (final row in (rows as List)) {
            await txn.insert(
              table,
              Map<String, dynamic>.from(row as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await _restoreLegacyTransactionImages(txn);
        await renameLegacyTags(txn);
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _restoreLegacyTransactionImages(DatabaseExecutor db) async {
    final legacyRows = await db.rawQuery('''
      SELECT t.id, t.image_path, t.created_at
      FROM ${Tables.transactions} t
      WHERE t.image_path IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM ${Tables.transactionImages} ti
          WHERE ti.transaction_id = t.id
        )
      ''');

    for (final row in legacyRows) {
      final txId = row['id'] as String?;
      final imagePath = row['image_path'] as String?;
      if (txId == null || imagePath == null || imagePath.isEmpty) continue;

      await db.insert(Tables.transactionImages, {
        'id': '${txId}_img_0',
        'transaction_id': txId,
        'image_path': imagePath,
        'sort_order': 0,
        'created_at':
            row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return GoogleDriveService(dbHelper);
});
