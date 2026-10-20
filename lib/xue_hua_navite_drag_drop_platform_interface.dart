import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xue_hua_navite_drag_drop_method_channel.dart';

abstract class XueHuaNaviteDragDropPlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteDragDropPlatform.
  XueHuaNaviteDragDropPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteDragDropPlatform _instance = MethodChannelXueHuaNaviteDragDrop();

  /// The default instance of [XueHuaNaviteDragDropPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteDragDrop].
  static XueHuaNaviteDragDropPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteDragDropPlatform] when
  /// they register themselves.
  static set instance(XueHuaNaviteDragDropPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
