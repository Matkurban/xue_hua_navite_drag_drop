import 'dart:typed_data';

import '../utils/file_reader.dart';

/// Callback signature for writing an async/virtual file to [targetPath]
/// when the user drops the item onto the OS desktop or folder.
typedef AsyncFileWriteCallback = Future<void> Function(String targetPath);

///Callback signature for providing in-memory bytes on demand.
typedef AsyncBytesProvider = Future<Uint8List> Function();

/// Configuration for an item to be dragged out of the Flutter app to the OS.
class DragOutItem {
  const DragOutItem._({
    required this.id,
    required this.fileName,
    this.filePath,
    this.mimeType,
    this.previewImage,
    this.onWriteFile,
    this.bytesProvider,
  });

  /// Mode A: Drag out an existing local file or folder by its absolute [filePath].
  factory DragOutItem.file({
    required String filePath,
    String? fileName,
    String? mimeType,
    Uint8List? previewImage,
  }) {
    final resolvedName = fileName ?? _extractFileName(filePath);
    return DragOutItem._(
      id: 'file_${DateTime.now().microsecondsSinceEpoch}_${resolvedName.hashCode}',
      fileName: resolvedName,
      filePath: filePath,
      mimeType: mimeType ?? _guessMimeType(resolvedName),
      previewImage: previewImage,
    );
  }

  /// Mode B1: Drag out a virtual/async file that will be written to `targetPath`
  /// when the OS requests the file content (e.g. via `NSFilePromiseProvider` on macOS
  /// or staging file on Windows/Linux/Mobile).
  factory DragOutItem.asyncFile({
    required String fileName,
    required AsyncFileWriteCallback onWriteFile,
    String? mimeType,
    Uint8List? previewImage,
    AsyncBytesProvider? webBytesProvider,
  }) {
    return DragOutItem._(
      id: 'async_${DateTime.now().microsecondsSinceEpoch}_${fileName.hashCode}',
      fileName: fileName,
      mimeType: mimeType ?? _guessMimeType(fileName),
      previewImage: previewImage,
      onWriteFile: onWriteFile,
      bytesProvider: webBytesProvider,
    );
  }

  /// Mode B2: Convenience constructor for dragging out in-memory [bytes] (or async bytes)
  /// as a file without manually creating a temporary file first.
  factory DragOutItem.memory({
    required String fileName,
    required AsyncBytesProvider bytesProvider,
    String? mimeType,
    Uint8List? previewImage,
  }) {
    return DragOutItem._(
      id: 'mem_${DateTime.now().microsecondsSinceEpoch}_${fileName.hashCode}',
      fileName: fileName,
      mimeType: mimeType ?? _guessMimeType(fileName),
      previewImage: previewImage,
      bytesProvider: bytesProvider,
      onWriteFile: (String targetPath) async {
        final data = await bytesProvider();
        await writeBytesToTargetFile(targetPath, data);
      },
    );
  }

  /// Unique task identifier used to correlate async file promise callbacks.
  final String id;

  /// Target file name (e.g. `clip.mp4`, `export.png`).
  final String fileName;

  /// Absolute local path if the file already exists on disk (`null` for async/memory items).
  final String? filePath;

  /// MIME type of the file.
  final String? mimeType;

  /// Optional PNG thumbnail bytes used as the native dragging preview image.
  final Uint8List? previewImage;

  /// Callback invoked to write the file to a destination path on disk.
  final AsyncFileWriteCallback? onWriteFile;

  /// Optional provider returning raw bytes (used on Web or memory mode).
  final AsyncBytesProvider? bytesProvider;

  /// Whether this item is generated asynchronously rather than existing on disk.
  bool get isAsync => filePath == null || filePath!.isEmpty;

  /// Serializes metadata for the platform method channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'mimeType': mimeType,
      'isAsync': isAsync,
      'previewImage': previewImage,
    };
  }

  static String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final index = trimmed.lastIndexOf('/');
    return index >= 0 ? trimmed.substring(index + 1) : trimmed;
  }

  static String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }
}
