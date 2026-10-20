import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelXueHuaNaviteDragDrop();
  const channel = MethodChannel('xue_hua_navite_drag_drop');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return '42';
        case 'initDragDrop':
        case 'setDropEffect':
          return null;
        case 'startDragOut':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('startDragOut invokes method channel and returns true', () async {
    final ok = await platform.startDragOut(
      items: <DragOutItem>[
        DragOutItem.file(filePath: '/tmp/test.mp4'),
      ],
      globalPosition: const Offset(100, 200),
    );
    expect(ok, isTrue);
  });
}
