import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_platform_interface.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockXueHuaNaviteDragDropPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteDragDropPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final XueHuaNaviteDragDropPlatform initialPlatform = XueHuaNaviteDragDropPlatform.instance;

  test('$MethodChannelXueHuaNaviteDragDrop is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteDragDrop>());
  });

  test('getPlatformVersion', () async {
    XueHuaNaviteDragDrop xueHuaNaviteDragDropPlugin = XueHuaNaviteDragDrop();
    MockXueHuaNaviteDragDropPlatform fakePlatform = MockXueHuaNaviteDragDropPlatform();
    XueHuaNaviteDragDropPlatform.instance = fakePlatform;

    expect(await xueHuaNaviteDragDropPlugin.getPlatformVersion(), '42');
  });
}
