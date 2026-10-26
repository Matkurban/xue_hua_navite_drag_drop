import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

/// Shared hooks so flutter_driver can exercise plugin APIs without OS DnD.
class DriverBridge {
  DriverBridge._();

  static DriverUiProbe? ui;

  /// Handles custom flutter_driver extension commands.
  static Future<String> handle(String? command) async {
    final cmd = command ?? '';
    switch (cmd) {
      case 'ping':
        return 'pong';
      case 'initDragDrop':
        await XueHuaNaviteDragDrop().initDragDrop();
        return 'ok';
      case 'platformReady':
        return XueHuaNaviteDragDropPlatform.instance.runtimeType.toString();
      case 'startDragOutMemory':
        return await _startDragOutMemory();
      case 'startDragOutFile':
        return await _startDragOutFile();
      case 'simulateDragEnter':
        final enterPos = ui?.dropCenter ?? const Offset(180, 220);
        DragDropManager.instance.handleDragEntered(enterPos);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return jsonEncode(<String, Object?>{
          'hovering': ui?.isHovering ?? false,
          'status': ui?.dragOutStatus,
          'pos': <double>[enterPos.dx, enterPos.dy],
        });
      case 'simulateDragUpdate':
        final updatePos = (ui?.dropCenter ?? const Offset(200, 240)) + const Offset(12, 8);
        DragDropManager.instance.handleDragUpdated(updatePos);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return jsonEncode(<String, Object?>{
          'hovering': ui?.isHovering ?? false,
          'hasHoverPosition': ui?.hoverPosition != null,
        });
      case 'simulateDragExit':
        DragDropManager.instance.handleDragExited();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return jsonEncode(<String, Object?>{
          'hovering': ui?.isHovering ?? false,
        });
      case 'simulatePerformDrop':
        return await _simulatePerformDrop();
      case 'uiState':
        return jsonEncode(<String, Object?>{
          'hovering': ui?.isHovering ?? false,
          'droppedCount': ui?.droppedCount ?? 0,
          'status': ui?.dragOutStatus ?? '',
          'firstDroppedName': ui?.firstDroppedName,
        });
      case 'cancelDragOut':
        DragDropManager.instance.handleDragOutEnded(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return jsonEncode(<String, Object?>{
          'status': ui?.dragOutStatus ?? '',
        });
      default:
        return 'unknown:$cmd';
    }
  }

  static Future<String> _startDragOutMemory() async {
    final plugin = XueHuaNaviteDragDrop();
    var completed = false;
    var success = false;
    final started = await plugin.startDragOut(
      items: <DragOutItem>[
        DragOutItem.memory(
          fileName: 'driver_export.txt',
          mimeType: 'text/plain',
          bytesProvider: () async =>
              Uint8List.fromList(utf8.encode('driver-memory-export')),
        ),
      ],
      globalPosition: const Offset(400, 300),
      onDragCompleted: (ok) {
        completed = true;
        success = ok;
      },
    );
    // Give native a moment; then end session so UI is not stuck in drag.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    DragDropManager.instance.handleDragOutEnded(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return jsonEncode(<String, Object?>{
      'started': started,
      'callbackSeen': completed,
      'success': success,
      'status': ui?.dragOutStatus ?? '',
    });
  }

  static Future<String> _startDragOutFile() async {
    final firstPath = ui?.firstDroppedPath;
    if (firstPath == null || firstPath.isEmpty) {
      return jsonEncode(<String, Object?>{
        'started': false,
        'error': 'no_dropped_file',
      });
    }
    final plugin = XueHuaNaviteDragDrop();
    final started = await plugin.startDragOut(
      items: <DragOutItem>[
        DragOutItem.file(filePath: firstPath),
      ],
      globalPosition: const Offset(400, 300),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    DragDropManager.instance.handleDragOutEnded(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return jsonEncode(<String, Object?>{
      'started': started,
      'status': ui?.dragOutStatus ?? '',
    });
  }

  static Future<String> _simulatePerformDrop() async {
    final items = <DropItem>[
      DropItem(
        name: 'driver_sample.txt',
        path: '/tmp/driver_sample.txt',
        isDirectory: false,
        size: 42,
        mimeType: 'text/plain',
      ),
      DropItem(
        name: 'driver_folder',
        path: '/tmp/driver_folder',
        isDirectory: true,
        size: 0,
        children: <DropItem>[
          DropItem(
            name: 'child.bin',
            path: '/tmp/driver_folder/child.bin',
            isDirectory: false,
            size: 8,
          ),
        ],
      ),
    ];
    final dropPos = ui?.dropCenter ?? const Offset(180, 220);
    await DragDropManager.instance.handlePerformDrop(
      dropPos,
      items,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return jsonEncode(<String, Object?>{
      'droppedCount': ui?.droppedCount ?? 0,
      'firstDroppedName': ui?.firstDroppedName,
      'hovering': ui?.isHovering ?? false,
    });
  }
}

/// UI probe registered by `_MyAppState` for driver commands.
class DriverUiProbe {
  DriverUiProbe({
    required this.isHoveringGetter,
    required this.hoverPositionGetter,
    required this.droppedCountGetter,
    required this.dragOutStatusGetter,
    required this.firstDroppedNameGetter,
    required this.firstDroppedPathGetter,
    required this.dropCenterGetter,
  });

  final bool Function() isHoveringGetter;
  final Offset? Function() hoverPositionGetter;
  final int Function() droppedCountGetter;
  final String Function() dragOutStatusGetter;
  final String? Function() firstDroppedNameGetter;
  final String? Function() firstDroppedPathGetter;
  final Offset? Function() dropCenterGetter;

  bool get isHovering => isHoveringGetter();

  Offset? get hoverPosition => hoverPositionGetter();

  int get droppedCount => droppedCountGetter();

  String get dragOutStatus => dragOutStatusGetter();

  String? get firstDroppedName => firstDroppedNameGetter();

  String? get firstDroppedPath => firstDroppedPathGetter();

  Offset? get dropCenter => dropCenterGetter();
}
