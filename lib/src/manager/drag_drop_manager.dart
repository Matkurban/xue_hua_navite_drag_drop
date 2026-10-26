import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../xue_hua_navite_drag_drop_platform_interface.dart';
import '../models/drag_event.dart';
import '../models/drag_out_item.dart';
import '../models/drop_item.dart';
import '../utils/file_reader.dart';

/// Internal registration entry for a mounted `NativeDropRegion`.
class DropRegionRegistration {
  DropRegionRegistration({
    required this.id,
    required this.getBounds,
    required this.isEnabled,
    this.onDragEnter,
    this.onDragUpdate,
    this.onDragExit,
    this.onPerformDrop,
  });

  final int id;
  final Rect? Function() getBounds;
  final bool Function() isEnabled;
  final void Function(NativeDragEvent event)? onDragEnter;
  final void Function(NativeDragEvent event)? onDragUpdate;
  final void Function()? onDragExit;
  final FutureOr<void> Function(NativeDropEvent event)? onPerformDrop;
}

/// Coordinates native window drag-and-drop events across registered [NativeDropRegion]
/// and [NativeDraggable] widgets.
class DragDropManager {
  DragDropManager._();

  /// Singleton instance of [DragDropManager].
  static final DragDropManager instance = DragDropManager._();

  final Map<int, DropRegionRegistration> _regions =
      <int, DropRegionRegistration>{};
  final Map<String, DragOutItem> _activeAsyncDragItems =
      <String, DragOutItem>{};

  int _nextRegionId = 1;
  int? _hoveredRegionId;
  bool _initialized = false;
  void Function(bool success)? _activeDragOutCallback;

  /// Initializes the platform drag-and-drop listener once.
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    XueHuaNaviteDragDropPlatform.instance.registerCallbackHandler(
      onDragEntered: handleDragEntered,
      onDragUpdated: handleDragUpdated,
      onDragExited: handleDragExited,
      onPerformDrop: handlePerformDrop,
      onRequestAsyncFileWrite: handleRequestAsyncFileWrite,
      onDragOutEnded: handleDragOutEnded,
    );
    await XueHuaNaviteDragDropPlatform.instance.initDragDrop();
  }

  /// Registers a [NativeDropRegion] and returns its unique registration ID.
  int registerRegion({
    required Rect? Function() getBounds,
    required bool Function() isEnabled,
    void Function(NativeDragEvent event)? onDragEnter,
    void Function(NativeDragEvent event)? onDragUpdate,
    void Function()? onDragExit,
    FutureOr<void> Function(NativeDropEvent event)? onPerformDrop,
  }) {
    ensureInitialized();
    final id = _nextRegionId++;
    _regions[id] = DropRegionRegistration(
      id: id,
      getBounds: getBounds,
      isEnabled: isEnabled,
      onDragEnter: onDragEnter,
      onDragUpdate: onDragUpdate,
      onDragExit: onDragExit,
      onPerformDrop: onPerformDrop,
    );
    return id;
  }

  /// Unregisters a previously registered [NativeDropRegion].
  void unregisterRegion(int id) {
    if (_hoveredRegionId == id) {
      _hoveredRegionId = null;
    }
    _regions.remove(id);
  }

  /// Starts a native drag-out session with the provided [items].
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
    void Function(bool success)? onDragCompleted,
  }) async {
    await ensureInitialized();
    final nativeItems = await _materializeItemsForNative(items);
    _activeAsyncDragItems.clear();
    for (final item in nativeItems) {
      if (item.isAsync) {
        _activeAsyncDragItems[item.id] = item;
      }
    }
    // Keep original async writers available when native requests deferred write.
    for (final item in items) {
      if (item.isAsync) {
        _activeAsyncDragItems.putIfAbsent(item.id, () => item);
      }
    }
    _activeDragOutCallback = onDragCompleted;
    final success = await XueHuaNaviteDragDropPlatform.instance.startDragOut(
      items: nativeItems,
      globalPosition: globalPosition,
    );
    if (!success && _activeDragOutCallback != null) {
      final cb = _activeDragOutCallback;
      _activeDragOutCallback = null;
      cb!(false);
    }
    return success;
  }

  /// Linux GTK drag-and-drop only accepts real `file://` URIs. Materialize
  /// async/memory items to temp files before handing them to the native side.
  Future<List<DragOutItem>> _materializeItemsForNative(
    List<DragOutItem> items,
  ) async {
    final needsStaging =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    if (!needsStaging) {
      return items;
    }

    final prepared = <DragOutItem>[];
    for (final item in items) {
      if (!item.isAsync || item.onWriteFile == null) {
        prepared.add(item);
        continue;
      }
      final targetPath = await createTempFilePathForDragOut(item.fileName);
      await item.onWriteFile!(targetPath);
      prepared.add(
        DragOutItem.file(
          filePath: targetPath,
          fileName: item.fileName,
          mimeType: item.mimeType,
          previewImage: item.previewImage,
        ),
      );
    }
    return prepared;
  }

  /// Handles native `onDragEntered` event.
  void handleDragEntered(Offset globalPosition) {
    _updateHoverState(globalPosition);
  }

  /// Handles native `onDragUpdated` event.
  void handleDragUpdated(Offset globalPosition) {
    _updateHoverState(globalPosition);
  }

  /// Handles native `onDragExited` event.
  void handleDragExited() {
    if (_hoveredRegionId != null) {
      final prev = _regions[_hoveredRegionId!];
      _hoveredRegionId = null;
      prev?.onDragExit?.call();
    }
  }

  /// Handles native `onPerformDrop` event and dispatches [items] to the hit region.
  Future<void> handlePerformDrop(
    Offset globalPosition,
    List<DropItem> items,
  ) async {
    final hit = _hitTest(globalPosition);
    if (_hoveredRegionId != null) {
      final prev = _regions[_hoveredRegionId!];
      _hoveredRegionId = null;
      prev?.onDragExit?.call();
    }
    if (hit != null && items.isNotEmpty) {
      final bounds = hit.getBounds();
      final localPos = bounds != null
          ? globalPosition - bounds.topLeft
          : globalPosition;
      await hit.onPerformDrop?.call(
        NativeDropEvent(
          globalPosition: globalPosition,
          localPosition: localPos,
          items: items,
        ),
      );
    }
  }

  /// Handles native request to materialize an async file at [destinationPath].
  Future<bool> handleRequestAsyncFileWrite(
    String itemId,
    String destinationPath,
  ) async {
    final item = _activeAsyncDragItems[itemId];
    if (item == null || item.onWriteFile == null) {
      return false;
    }
    try {
      await item.onWriteFile!(destinationPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Handles native notification that a drag-out session finished.
  void handleDragOutEnded(bool success) {
    final cb = _activeDragOutCallback;
    _activeDragOutCallback = null;
    cb?.call(success);
  }

  void _updateHoverState(Offset globalPosition) {
    final hit = _hitTest(globalPosition);
    final newId = hit?.id;

    if (newId != _hoveredRegionId) {
      if (_hoveredRegionId != null) {
        _regions[_hoveredRegionId!]?.onDragExit?.call();
      }
      _hoveredRegionId = newId;
      if (hit != null) {
        final bounds = hit.getBounds();
        final localPos = bounds != null
            ? globalPosition - bounds.topLeft
            : globalPosition;
        hit.onDragEnter?.call(
          NativeDragEvent(
            globalPosition: globalPosition,
            localPosition: localPos,
          ),
        );
      }
      XueHuaNaviteDragDropPlatform.instance.setDropEffect(
        hit != null ? DropOperation.copy : DropOperation.none,
      );
    }

    if (hit != null) {
      final bounds = hit.getBounds();
      final localPos = bounds != null
          ? globalPosition - bounds.topLeft
          : globalPosition;
      hit.onDragUpdate?.call(
        NativeDragEvent(
          globalPosition: globalPosition,
          localPosition: localPos,
        ),
      );
    }
  }

  DropRegionRegistration? _hitTest(Offset globalPosition) {
    final entries = _regions.values.toList().reversed;
    for (final region in entries) {
      if (!region.isEnabled()) {
        continue;
      }
      final bounds = region.getBounds();
      if (bounds != null && bounds.contains(globalPosition)) {
        return region;
      }
    }
    return null;
  }
}
