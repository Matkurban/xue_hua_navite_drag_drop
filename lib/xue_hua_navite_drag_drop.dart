import 'dart:ui';

import 'src/manager/drag_drop_manager.dart';
import 'src/models/drag_out_item.dart';

export 'src/manager/drag_drop_manager.dart';
export 'src/models/drag_event.dart';
export 'src/models/drag_out_item.dart';
export 'src/models/drop_item.dart';
export 'src/widgets/native_draggable.dart';
export 'src/widgets/native_drop_region.dart';
export 'xue_hua_navite_drag_drop_platform_interface.dart';

/// Main facade for the `xue_hua_navite_drag_drop` plugin.
class XueHuaNaviteDragDrop {
  /// Explicitly initializes the native drag-and-drop system if needed before
  /// mounting a `NativeDropRegion`.
  Future<void> initDragDrop() {
    return DragDropManager.instance.ensureInitialized();
  }

  /// Programmatically starts a native drag-out session with [items].
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
    void Function(bool success)? onDragCompleted,
  }) {
    return DragDropManager.instance.startDragOut(
      items: items,
      globalPosition: globalPosition,
      onDragCompleted: onDragCompleted,
    );
  }
}
