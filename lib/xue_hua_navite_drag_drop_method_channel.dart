import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/drag_event.dart';
import 'src/models/drag_out_item.dart';
import 'src/models/drop_item.dart';
import 'xue_hua_navite_drag_drop_platform_interface.dart';

/// An implementation of [XueHuaNaviteDragDropPlatform] that uses method channels.
class MethodChannelXueHuaNaviteDragDrop extends XueHuaNaviteDragDropPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xue_hua_navite_drag_drop');

  void Function(Offset globalPosition)? _onDragEntered;
  void Function(Offset globalPosition)? _onDragUpdated;
  void Function()? _onDragExited;
  Future<void> Function(Offset globalPosition, List<DropItem> items)?
      _onPerformDrop;
  Future<bool> Function(String itemId, String destinationPath)?
      _onRequestAsyncFileWrite;
  void Function(bool success)? _onDragOutEnded;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

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
  }) {
    _onDragEntered = onDragEntered;
    _onDragUpdated = onDragUpdated;
    _onDragExited = onDragExited;
    _onPerformDrop = onPerformDrop;
    _onRequestAsyncFileWrite = onRequestAsyncFileWrite;
    _onDragOutEnded = onDragOutEnded;
    methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  @override
  Future<void> initDragDrop() async {
    try {
      await methodChannel.invokeMethod<void>('initDragDrop');
    } on MissingPluginException {
      // Ignored in unit tests or unsupported headless environments.
    }
  }

  @override
  Future<void> setDropEffect(DropOperation operation) async {
    try {
      await methodChannel.invokeMethod<void>('setDropEffect', <String, Object?>{
        'operation': operation.name,
      });
    } on MissingPluginException {
      // Ignored when native side does not require explicit cursor updates.
    }
  }

  @override
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
  }) async {
    final result = await methodChannel.invokeMethod<bool>(
      'startDragOut',
      <String, Object?>{
        'items': items.map((e) => e.toMap()).toList(),
        'x': globalPosition?.dx ?? 0.0,
        'y': globalPosition?.dy ?? 0.0,
      },
    );
    return result ?? false;
  }

  Future<Object?> _handleNativeMethodCall(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>? ??
        const <Object?, Object?>{};
    switch (call.method) {
      case 'onDragEntered':
        final pos = _parseOffset(args);
        _onDragEntered?.call(pos);
        return null;
      case 'onDragUpdated':
        final pos = _parseOffset(args);
        _onDragUpdated?.call(pos);
        return null;
      case 'onDragExited':
        _onDragExited?.call();
        return null;
      case 'onPerformDrop':
        final pos = _parseOffset(args);
        final rawItems = args['items'] as List<Object?>? ?? const <Object?>[];
        final items = rawItems
            .whereType<Map<Object?, Object?>>()
            .map(DropItem.fromMap)
            .toList(growable: false);
        await _onPerformDrop?.call(pos, items);
        return null;
      case 'onRequestAsyncFileWrite':
        final itemId = args['id'] as String? ?? '';
        final destinationPath = args['destinationPath'] as String? ?? '';
        if (_onRequestAsyncFileWrite != null &&
            itemId.isNotEmpty &&
            destinationPath.isNotEmpty) {
          return await _onRequestAsyncFileWrite!(itemId, destinationPath);
        }
        return false;
      case 'onDragOutEnded':
        final success = (args['success'] as bool?) ?? true;
        _onDragOutEnded?.call(success);
        return null;
      default:
        return null;
    }
  }

  Offset _parseOffset(Map<Object?, Object?> map) {
    final dx = (map['x'] as num?)?.toDouble() ?? 0.0;
    final dy = (map['y'] as num?)?.toDouble() ?? 0.0;
    return Offset(dx, dy);
  }
}
