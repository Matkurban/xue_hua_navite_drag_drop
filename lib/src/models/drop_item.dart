import 'dart:typed_data';

import '../utils/file_reader.dart';

/// Represents a file or folder dragged into the Flutter application.
class DropItem {
  /// Creates a [DropItem] instance.
  const DropItem({
    required this.name,
    this.path,
    this.uri,
    required this.isDirectory,
    this.size = 0,
    this.mimeType,
    this.children = const <DropItem>[],
    this.bookmark,
    this._webFile,
    this._rawBytes,
  });

  /// Creates a [DropItem] from a platform channel map payload.
  factory DropItem.fromMap(Map<Object?, Object?> map) {
    final rawChildren = map['children'] as List<Object?>?;
    final parsedChildren = rawChildren != null
        ? rawChildren
              .whereType<Map<Object?, Object?>>()
              .map(DropItem.fromMap)
              .toList(growable: false)
        : const <DropItem>[];

    final pathStr = map['path'] as String?;
    final nameStr =
        (map['name'] as String?) ??
        (pathStr != null ? _basename(pathStr) : 'unknown');

    return DropItem(
      name: nameStr,
      path: pathStr,
      uri: map['uri'] as String?,
      isDirectory: (map['isDirectory'] as bool?) ?? false,
      size: (map['size'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String?,
      children: parsedChildren,
      bookmark: map['bookmark'] as String?,
      rawBytes: map['bytes'] as Uint8List?,
    );
  }

  /// File or directory display name (including extension for files).
  final String name;

  /// Absolute local filesystem path on Desktop/Mobile platforms.
  /// On Web, this is the virtual relative path (e.g. `/folder/video.mp4`) or `null`.
  final String? path;

  /// Original platform URI (`file://` or `content://`) when available.
  final String? uri;

  /// Whether this dropped item is a directory/folder.
  final bool isDirectory;

  /// Size in bytes (0 for directories unless aggregated).
  final int size;

  /// Optional MIME type (e.g. `video/mp4`, `image/png`).
  final String? mimeType;

  /// Child entries when [isDirectory] is `true`.
  final List<DropItem> children;

  /// Security-scoped bookmark base64 string on macOS (if sandboxed).
  final String? bookmark;

  final Object? _webFile;
  final Uint8List? _rawBytes;

  /// Reads the entire file content into memory as a [Uint8List].
  /// Returns an empty [Uint8List] if [isDirectory] is `true`.
  Future<Uint8List> readAsBytes() async {
    if (isDirectory) {
      return Uint8List(0);
    }
    if (_rawBytes != null) {
      return _rawBytes;
    }
    return readPlatformFileBytes(path, _webFile);
  }

  /// Opens a chunked byte stream for reading large files (such as videos)
  /// without loading the whole file into memory at once.
  Stream<Uint8List> openRead([int? start, int? end]) {
    if (isDirectory) {
      return const Stream<Uint8List>.empty();
    }
    if (_rawBytes != null) {
      final sub = _rawBytes.sublist(
        start ?? 0,
        end != null && end < _rawBytes.length ? end : _rawBytes.length,
      );
      return Stream<Uint8List>.value(sub);
    }
    return openPlatformFileRead(path, _webFile, start, end);
  }

  /// Converts this [DropItem] into a serializable map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'path': path,
      'uri': uri,
      'isDirectory': isDirectory,
      'size': size,
      'mimeType': mimeType,
      'bookmark': bookmark,
      'children': children.map((e) => e.toMap()).toList(),
    };
  }

  static String _basename(String fullPath) {
    final normalized = fullPath.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final idx = trimmed.lastIndexOf('/');
    return idx >= 0 ? trimmed.substring(idx + 1) : trimmed;
  }

  @override
  String toString() =>
      'DropItem(name: $name, path: $path, isDirectory: $isDirectory, size: $size, children: ${children.length})';
}
