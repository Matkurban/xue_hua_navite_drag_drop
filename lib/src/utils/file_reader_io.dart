import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readPlatformFileBytes(String? path, Object? webFile) async {
  if (path == null || path.isEmpty) {
    return Uint8List(0);
  }
  final file = File(path);
  if (!await file.exists()) {
    return Uint8List(0);
  }
  return file.readAsBytes();
}

Stream<Uint8List> openPlatformFileRead(
  String? path,
  Object? webFile, [
  int? start,
  int? end,
]) async* {
  if (path == null || path.isEmpty) {
    return;
  }
  final file = File(path);
  if (!await file.exists()) {
    return;
  }
  await for (final chunk in file.openRead(start, end)) {
    yield chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
  }
}

Future<void> writeBytesToTargetFile(String targetPath, Uint8List bytes) async {
  final file = File(targetPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}
