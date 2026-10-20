import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../manager/drag_drop_manager.dart';
import '../models/drag_out_item.dart';

/// A widget that allows dragging files, videos, or dynamically generated files
/// out of the Flutter application to the OS desktop, Finder, Explorer, or other apps.
class NativeDraggable extends StatefulWidget {
  /// Creates a [NativeDraggable] widget.
  const NativeDraggable({
    super.key,
    required this.child,
    required this.itemsBuilder,
    this.enabled = true,
    this.dragThreshold = 6.0,
    this.captureWidgetSnapshotAsPreview = true,
    this.onDragStarted,
    this.onDragCompleted,
  });

  /// The widget that initiates the drag gesture.
  final Widget child;

  /// Callback returning the list of [DragOutItem]s to drag out when a drag starts.
  final Future<List<DragOutItem>> Function() itemsBuilder;

  /// Whether dragging out is enabled.
  final bool enabled;

  /// Pointer travel distance in logical pixels before triggering a desktop drag session.
  final double dragThreshold;

  /// Whether to automatically capture a PNG snapshot of [child] as the native
  /// drag preview image if an item does not specify its own `previewImage`.
  final bool captureWidgetSnapshotAsPreview;

  /// Called when the native drag-out session begins.
  final VoidCallback? onDragStarted;

  /// Called when the native drag-out session completes or is cancelled.
  final void Function(bool success)? onDragCompleted;

  @override
  State<NativeDraggable> createState() => _NativeDraggableState();
}

class _NativeDraggableState extends State<NativeDraggable> {
  final GlobalKey _repaintKey = GlobalKey();
  Offset? _pointerDownPosition;
  bool _isDragging = false;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<Uint8List?> _capturePreviewSnapshot() async {
    if (!widget.captureWidgetSnapshotAsPreview) {
      return null;
    }
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _triggerDragOut(Offset globalPosition) async {
    if (_isDragging || !widget.enabled) {
      return;
    }
    _isDragging = true;
    try {
      final rawItems = await widget.itemsBuilder();
      if (rawItems.isEmpty) {
        _isDragging = false;
        return;
      }
      final snapshot = await _capturePreviewSnapshot();
      final enrichedItems = rawItems.map((item) {
        if (item.previewImage != null || snapshot == null) {
          return item;
        }
        if (item.isAsync && item.onWriteFile != null) {
          return DragOutItem.asyncFile(
            fileName: item.fileName,
            onWriteFile: item.onWriteFile!,
            mimeType: item.mimeType,
            previewImage: snapshot,
            webBytesProvider: item.bytesProvider,
          );
        } else if (item.filePath != null) {
          return DragOutItem.file(
            filePath: item.filePath!,
            fileName: item.fileName,
            mimeType: item.mimeType,
            previewImage: snapshot,
          );
        }
        return item;
      }).toList();

      widget.onDragStarted?.call();
      await DragDropManager.instance.startDragOut(
        items: enrichedItems,
        globalPosition: globalPosition,
        onDragCompleted: (success) {
          _isDragging = false;
          widget.onDragCompleted?.call(success);
        },
      );
    } finally {
      _pointerDownPosition = null;
      _isDragging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = RepaintBoundary(
      key: _repaintKey,
      child: widget.child,
    );

    if (_isMobilePlatform) {
      return GestureDetector(
        onLongPressStart: widget.enabled
            ? (details) => _triggerDragOut(details.globalPosition)
            : null,
        child: content,
      );
    }

    return Listener(
      onPointerDown: widget.enabled
          ? (PointerDownEvent event) {
              if (event.buttons == kPrimaryMouseButton || event.buttons == 0) {
                _pointerDownPosition = event.position;
              }
            }
          : null,
      onPointerMove: widget.enabled
          ? (PointerMoveEvent event) {
              final start = _pointerDownPosition;
              if (start != null && !_isDragging) {
                final distance = (event.position - start).distance;
                if (distance >= widget.dragThreshold) {
                  _pointerDownPosition = null;
                  _triggerDragOut(event.position);
                }
              }
            }
          : null,
      onPointerUp: (_) => _pointerDownPosition = null,
      onPointerCancel: (_) => _pointerDownPosition = null,
      child: content,
    );
  }
}
