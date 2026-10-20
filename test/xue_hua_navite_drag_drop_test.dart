import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_method_channel.dart';

class MockXueHuaNaviteDragDropPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteDragDropPlatform {
  DropOperation? lastOperation;
  List<DragOutItem>? lastDragOutItems;

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
  Future<void> setDropEffect(DropOperation operation) async {
    lastOperation = operation;
  }

  @override
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
  }) async {
    lastDragOutItems = items;
    return true;
  }
}

void main() {
  final XueHuaNaviteDragDropPlatform initialPlatform =
      XueHuaNaviteDragDropPlatform.instance;

  test('$MethodChannelXueHuaNaviteDragDrop is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteDragDrop>());
  });

  test('startDragOut delegates to platform implementation', () async {
    final plugin = XueHuaNaviteDragDrop();
    final fakePlatform = MockXueHuaNaviteDragDropPlatform();
    XueHuaNaviteDragDropPlatform.instance = fakePlatform;

    final ok = await plugin.startDragOut(
      items: <DragOutItem>[
        DragOutItem.file(filePath: '/tmp/video.mp4'),
      ],
    );
    expect(ok, isTrue);
    expect(fakePlatform.lastDragOutItems?.length, 1);
  });

  test('DropItem parses file and folder hierarchy from map', () async {
    final rawMap = <Object?, Object?>{
      'name': 'project_folder',
      'path': '/Users/demo/project_folder',
      'isDirectory': true,
      'size': 2048,
      'children': <Object?>[
        <Object?, Object?>{
          'name': 'demo.mp4',
          'path': '/Users/demo/project_folder/demo.mp4',
          'isDirectory': false,
          'size': 2048,
          'mimeType': 'video/mp4',
          'bytes': Uint8List.fromList(<int>[1, 2, 3, 4]),
        },
      ],
    };

    final folder = DropItem.fromMap(rawMap);
    expect(folder.name, 'project_folder');
    expect(folder.isDirectory, isTrue);
    expect(folder.children.length, 1);

    final child = folder.children.first;
    expect(child.name, 'demo.mp4');
    expect(child.isDirectory, isFalse);
    expect(child.mimeType, 'video/mp4');
    expect(await child.readAsBytes(), Uint8List.fromList(<int>[1, 2, 3, 4]));
  });

  test('DragOutItem supports both local file and async file modes', () async {
    final localItem = DragOutItem.file(filePath: '/tmp/sample_video.mp4');
    expect(localItem.isAsync, isFalse);
    expect(localItem.fileName, 'sample_video.mp4');
    expect(localItem.mimeType, 'video/mp4');

    String? writtenTarget;
    final asyncItem = DragOutItem.asyncFile(
      fileName: 'generated.mp4',
      onWriteFile: (targetPath) async {
        writtenTarget = targetPath;
      },
    );
    expect(asyncItem.isAsync, isTrue);
    await asyncItem.onWriteFile!('/tmp/out/generated.mp4');
    expect(writtenTarget, '/tmp/out/generated.mp4');
  });
}
