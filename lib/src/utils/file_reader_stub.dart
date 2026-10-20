import 'dart:typed_data';

Future<Uint8List> readPlatformFileBytes(String? path, Object? webFile) {
  throw UnsupportedError(
    'Cannot read file without dart:io or web implementation.',
  );
}

Stream<Uint8List> openPlatformFileRead(
  String? path,
  Object? webFile, [
  int? start,
  int? end,
]) {
  throw UnsupportedError(
    'Cannot stream file without dart:io or web implementation.',
  );
}

Future<void> writeBytesToTargetFile(String targetPath, Uint8List bytes) {
  throw UnsupportedError(
    'Cannot write file without dart:io or web implementation.',
  );
}
