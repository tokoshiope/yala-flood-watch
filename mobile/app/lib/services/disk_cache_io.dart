import 'dart:io';
import 'dart:typed_data';

/// Native IO implementation (iOS / macOS / Android) for atomic disk caching of snapshots and map tiles.
bool get isFlutterTestEnv => Platform.environment.containsKey('FLUTTER_TEST');

File? _resolveSnapshotFile(Object? customFile, String defaultFilename) {
  if (customFile is File) return customFile;
  if (isFlutterTestEnv) return null;
  return File('${Directory.systemTemp.path}${Platform.pathSeparator}$defaultFilename');
}

Future<String?> readSnapshotFile(Object? customFile, String defaultFilename) async {
  final file = _resolveSnapshotFile(customFile, defaultFilename);
  if (file == null) return null;
  try {
    if (await file.exists()) {
      final txt = await file.readAsString();
      if (txt.isNotEmpty) return txt;
    }
  } catch (_) {}
  return null;
}

Future<bool> writeSnapshotFile(
  Object? customFile,
  String defaultFilename,
  String content,
) async {
  final file = _resolveSnapshotFile(customFile, defaultFilename);
  if (file == null) return false;
  try {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> deleteSnapshotFile(Object? customFile, String defaultFilename) async {
  final file = _resolveSnapshotFile(customFile, defaultFilename);
  if (file == null) return;
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

Directory _tileDir(String subdir) => Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$subdir',
    );

File _tileFile(String subdir, String filename) => File(
      '${_tileDir(subdir).path}${Platform.pathSeparator}$filename',
    );

Future<Uint8List?> readTileFile(String subdir, String filename) async {
  if (isFlutterTestEnv) return null;
  try {
    final file = _tileFile(subdir, filename);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

Future<void> deleteTileFile(String subdir, String filename) async {
  if (isFlutterTestEnv) return;
  try {
    final file = _tileFile(subdir, filename);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

Future<bool> writeTileFile(String subdir, String filename, Uint8List data) async {
  if (isFlutterTestEnv) return false;
  try {
    final dir = _tileDir(subdir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = _tileFile(subdir, filename);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(data, flush: false);
    await tmp.rename(file.path);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> evictTileCacheOverflow(String subdir, int maxFiles) async {
  if (isFlutterTestEnv) return;
  try {
    final dir = _tileDir(subdir);
    if (!await dir.exists()) return;
    final files = <({File file, DateTime modified})>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        try {
          final stat = await entity.stat();
          files.add((file: entity, modified: stat.modified));
        } catch (_) {}
      }
    }
    if (files.length <= maxFiles) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    final removeCount = files.length - maxFiles + 40;
    for (var i = 0; i < removeCount && i < files.length; i++) {
      try {
        await files[i].file.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

Future<void> clearTileCacheDir(String subdir) async {
  try {
    final dir = _tileDir(subdir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
