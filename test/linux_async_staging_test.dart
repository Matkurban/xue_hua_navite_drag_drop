import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

class _CapturingPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteDragDropPlatform {
  List<DragOutItem>? lastItems;

  @override
  void registerCallbackHandler({
    required void Function(Offset globalPosition) onDragEntered,
    required void Function(Offset globalPosition) onDragUpdated,
    required void Function() onDragExited,
    required Future<void> Function(Offset globalPosition, List<DropItem> items)
        onPerformDrop,
    required Future<bool> Function(String itemId, String destinationPath)
        onRequestAsyncFileWrite,
    required void Function(bool success) onDragOutEnded,
  }) {}

  @override
  Future<void> initDragDrop() async {}

  @override
  Future<void> setDropEffect(DropOperation operation) async {}

  @override
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
  }) async {
    lastItems = items;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Linux materializes async/memory drag-out items to temp files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final fake = _CapturingPlatform();
    XueHuaNaviteDragDropPlatform.instance = fake;

    final ok = await XueHuaNaviteDragDrop().startDragOut(
      items: <DragOutItem>[
        DragOutItem.memory(
          fileName: 'staged_note.txt',
          mimeType: 'text/plain',
          bytesProvider: () async =>
              Uint8List.fromList('hello-linux-stage'.codeUnits),
        ),
      ],
    );

    expect(ok, isTrue);
    expect(fake.lastItems, isNotNull);
    expect(fake.lastItems, hasLength(1));
    final staged = fake.lastItems!.single;
    expect(staged.isAsync, isFalse);
    expect(staged.filePath, isNotNull);
    expect(File(staged.filePath!).existsSync(), isTrue);
    expect(
      File(staged.filePath!).readAsStringSync(),
      'hello-linux-stage',
    );
  });
}
