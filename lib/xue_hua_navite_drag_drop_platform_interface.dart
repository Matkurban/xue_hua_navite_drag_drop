import 'dart:ui';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/drag_event.dart';
import 'src/models/drag_out_item.dart';
import 'src/models/drop_item.dart';
import 'xue_hua_navite_drag_drop_method_channel.dart';

abstract class XueHuaNaviteDragDropPlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteDragDropPlatform.
  XueHuaNaviteDragDropPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteDragDropPlatform _instance =
      MethodChannelXueHuaNaviteDragDrop();

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

  /// Returns the current operating system version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Registers native-to-Dart drag-and-drop lifecycle callbacks.
  void registerCallbackHandler({
    required void Function(Offset globalPosition) onDragEntered,
    required void Function(Offset globalPosition) onDragUpdated,
    required void Function() onDragExited,
    required Future<void> Function(Offset globalPosition, List<DropItem> items)
        onPerformDrop,
    required Future<bool> Function(String itemId, String destinationPath)
        onRequestAsyncFileWrite,
    required void Function(bool success) onDragOutEnded,
  }) {
    throw UnimplementedError(
      'registerCallbackHandler() has not been implemented.',
    );
  }

  /// Initializes native drop target registration on the active Flutter window/view.
  Future<void> initDragDrop() {
    throw UnimplementedError('initDragDrop() has not been implemented.');
  }

  /// Updates the native cursor drop effect (`copy`, `move`, `none`, etc.).
  Future<void> setDropEffect(DropOperation operation) {
    throw UnimplementedError('setDropEffect() has not been implemented.');
  }

  /// Starts an outbound native drag session to drag [items] to the OS desktop/files.
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
  }) {
    throw UnimplementedError('startDragOut() has not been implemented.');
  }
}
