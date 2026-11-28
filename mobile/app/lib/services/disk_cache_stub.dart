import 'dart:typed_data';

/// Web stub for disk cache operations (Safari/Web uses browser HTTP cache + SharedPreferences/localStorage).
bool get isFlutterTestEnv => false;

Future<String?> readSnapshotFile(Object? customFile, String defaultFilename) async => null;

Future<bool> writeSnapshotFile(Object? customFile, String defaultFilename, String content) async => false;

Future<void> deleteSnapshotFile(Object? customFile, String defaultFilename) async {}

Future<Uint8List?> readTileFile(String subdir, String filename) async => null;

Future<void> deleteTileFile(String subdir, String filename) async {}

Future<bool> writeTileFile(String subdir, String filename, Uint8List data) async => false;

Future<void> evictTileCacheOverflow(String subdir, int maxFiles) async {}

Future<void> clearTileCacheDir(String subdir) async {}
