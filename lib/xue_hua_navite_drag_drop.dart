
import 'xue_hua_navite_drag_drop_platform_interface.dart';

class XueHuaNaviteDragDrop {
  Future<String?> getPlatformVersion() {
    return XueHuaNaviteDragDropPlatform.instance.getPlatformVersion();
  }
}
