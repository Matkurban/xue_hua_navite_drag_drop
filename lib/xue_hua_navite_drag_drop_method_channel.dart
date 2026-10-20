import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'xue_hua_navite_drag_drop_platform_interface.dart';

/// An implementation of [XueHuaNaviteDragDropPlatform] that uses method channels.
class MethodChannelXueHuaNaviteDragDrop extends XueHuaNaviteDragDropPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xue_hua_navite_drag_drop');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
