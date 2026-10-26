import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List> readPlatformFileBytes(String? path, Object? webFile) async {
  if (!webFile.isA<web.Blob>()) {
    return Uint8List(0);
  }
  final blob = webFile as web.Blob;
  final arrayBuffer = await blob.arrayBuffer().toDart;
  return arrayBuffer.toDart.asUint8List();
}

Stream<Uint8List> openPlatformFileRead(
  String? path,
  Object? webFile, [
  int? start,
  int? end,
]) async* {
  if (!webFile.isA<web.Blob>()) {
    return;
  }
  final blob = webFile as web.Blob;
  const int chunkSize = 256 * 1024; // 256 KB chunks
  final int totalSize = blob.size;
  final int actualStart = start ?? 0;
  final int actualEnd = (end != null && end < totalSize) ? end : totalSize;

  int offset = actualStart;
  while (offset < actualEnd) {
    final int nextEnd = (offset + chunkSize < actualEnd)
        ? offset + chunkSize
        : actualEnd;
    final slice = blob.slice(offset, nextEnd);
    final arrayBuffer = await slice.arrayBuffer().toDart;
    yield arrayBuffer.toDart.asUint8List();
    offset = nextEnd;
  }
}

Future<void> writeBytesToTargetFile(String targetPath, Uint8List bytes) async {
  // On Web, file saving is handled via Blob URL / DownloadURL in XueHuaNaviteDragDropWeb.
}


Future<String> createTempFilePathForDragOut(String fileName) async {
  // Web drag-out uses in-memory Blob / DownloadURL instead of temp files.
  return fileName;
}
