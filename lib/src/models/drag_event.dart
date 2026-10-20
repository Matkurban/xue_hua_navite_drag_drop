import 'dart:ui';

import 'drop_item.dart';

/// Supported drop operation effects shown by the OS cursor.
enum DropOperation {
  /// Disallow dropping at the current cursor location.
  none,

  /// Copy the dragged files/folders to the target.
  copy,

  /// Move the dragged files/folders to the target.
  move,

  /// Link the dragged files/folders.
  link,
}

/// Base class for drag-in lifecycle events.
class NativeDragEvent {
  /// Creates a [NativeDragEvent] with window-relative logical coordinates.
  const NativeDragEvent({required this.globalPosition, this.localPosition});

  /// Logical pixel position relative to the Flutter window root.
  final Offset globalPosition;

  /// Logical pixel position relative to the target `NativeDropRegion` widget.
  final Offset? localPosition;

  /// Returns a copy of this event with a computed [localPosition].
  NativeDragEvent copyWithLocal(Offset localPos) {
    return NativeDragEvent(
      globalPosition: globalPosition,
      localPosition: localPos,
    );
  }
}

/// Event fired when the user releases the mouse/finger and drops files/folders.
class NativeDropEvent extends NativeDragEvent {
  /// Creates a [NativeDropEvent] containing the dropped [items].
  const NativeDropEvent({
    required super.globalPosition,
    super.localPosition,
    required this.items,
  });

  /// List of files and folders dropped by the user.
  final List<DropItem> items;

  @override
  NativeDropEvent copyWithLocal(Offset localPos) {
    return NativeDropEvent(
      globalPosition: globalPosition,
      localPosition: localPos,
      items: items,
    );
  }
}
