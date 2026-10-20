import 'dart:async';
import 'package:flutter/widgets.dart';

import '../manager/drag_drop_manager.dart';
import '../models/drag_event.dart';

/// A widget that receives files and folders dragged from the operating system
/// (Finder, Explorer, File Manager, iPadOS/Android split-screen, or Web desktop).
class NativeDropRegion extends StatefulWidget {
  /// Creates a [NativeDropRegion].
  const NativeDropRegion({
    super.key,
    required this.child,
    this.enabled = true,
    this.onDragEnter,
    this.onDragUpdate,
    this.onDragExit,
    this.onPerformDrop,
  });

  /// The child widget wrapped by this drop target region.
  final Widget child;

  /// Whether this drop region currently accepts drops.
  final bool enabled;

  /// Called when an OS drag cursor enters the bounds of this widget.
  final void Function(NativeDragEvent event)? onDragEnter;

  /// Called continuously while an OS drag cursor moves inside this widget.
  final void Function(NativeDragEvent event)? onDragUpdate;

  /// Called when an OS drag cursor leaves the bounds of this widget.
  final VoidCallback? onDragExit;

  /// Called when the user drops files or folders inside this widget.
  final FutureOr<void> Function(NativeDropEvent event)? onPerformDrop;

  @override
  State<NativeDropRegion> createState() => _NativeDropRegionState();
}

class _NativeDropRegionState extends State<NativeDropRegion> {
  final GlobalKey _regionKey = GlobalKey();
  int? _registrationId;

  @override
  void initState() {
    super.initState();
    _registrationId = DragDropManager.instance.registerRegion(
      getBounds: _computeGlobalBounds,
      isEnabled: () => mounted && widget.enabled,
      onDragEnter: (event) => widget.onDragEnter?.call(event),
      onDragUpdate: (event) => widget.onDragUpdate?.call(event),
      onDragExit: () => widget.onDragExit?.call(),
      onPerformDrop: (event) => widget.onPerformDrop?.call(event),
    );
  }

  @override
  void dispose() {
    if (_registrationId != null) {
      DragDropManager.instance.unregisterRegion(_registrationId!);
    }
    super.dispose();
  }

  Rect? _computeGlobalBounds() {
    final context = _regionKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _regionKey,
      child: widget.child,
    );
  }
}
