import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

/// Shared hooks so flutter_driver can exercise plugin APIs without OS DnD.
class DriverBridge {
  DriverBridge._();

  static DriverUiProbe? ui;
  static Directory? _tempDir;

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
      case 'startDragOutEmpty':
        return await _startDragOutEmpty();
      case 'startDragOutMissingFile':
        return await _startDragOutMissingFile();
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
        final updatePos =
            (ui?.dropCenter ?? const Offset(200, 240)) + const Offset(12, 8);
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

  static Future<Directory> _ensureTempDir() async {
    final existing = _tempDir;
    if (existing != null && await existing.exists()) {
      return existing;
    }
    final created =
        await Directory.systemTemp.createTemp('xh_drag_driver_');
    _tempDir = created;
    return created;
  }

  static Future<String> _waitForDragOutResult({
    required Future<bool> Function() start,
    required bool Function() completedGetter,
    required bool Function() successGetter,
  }) async {
    final started = await start();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!completedGetter() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (!completedGetter()) {
      DragDropManager.instance.handleDragOutEnded(false);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return jsonEncode(<String, Object?>{
      'started': started,
      'callbackSeen': completedGetter(),
      'success': successGetter(),
      'status': ui?.dragOutStatus ?? '',
    });
  }

  static Future<String> _startDragOutMemory() async {
    final plugin = XueHuaNaviteDragDrop();
    var completed = false;
    var success = false;
    return _waitForDragOutResult(
      start: () => plugin.startDragOut(
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
      ),
      completedGetter: () => completed,
      successGetter: () => success,
    );
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
    var completed = false;
    var success = false;
    return _waitForDragOutResult(
      start: () => plugin.startDragOut(
        items: <DragOutItem>[
          DragOutItem.file(filePath: firstPath),
        ],
        globalPosition: const Offset(400, 300),
        onDragCompleted: (ok) {
          completed = true;
          success = ok;
        },
      ),
      completedGetter: () => completed,
      successGetter: () => success,
    );
  }

  static Future<String> _startDragOutEmpty() async {
    final plugin = XueHuaNaviteDragDrop();
    var completed = false;
    var success = false;
    final started = await plugin.startDragOut(
      items: const <DragOutItem>[],
      globalPosition: const Offset(400, 300),
      onDragCompleted: (ok) {
        completed = true;
        success = ok;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return jsonEncode(<String, Object?>{
      'started': started,
      'callbackSeen': completed,
      'success': success,
    });
  }

  static Future<String> _startDragOutMissingFile() async {
    final plugin = XueHuaNaviteDragDrop();
    var completed = false;
    var success = false;
    final missing = Platform.isWindows
        ? r'C:\xh_driver_missing\no_such_file.txt'
        : '/tmp/xh_driver_missing/no_such_file.txt';
    final started = await plugin.startDragOut(
      items: <DragOutItem>[
        DragOutItem.file(filePath: missing),
      ],
      globalPosition: const Offset(400, 300),
      onDragCompleted: (ok) {
        completed = true;
        success = ok;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return jsonEncode(<String, Object?>{
      'started': started,
      'callbackSeen': completed,
      'success': success,
    });
  }

  static Future<String> _simulatePerformDrop() async {
    final temp = await _ensureTempDir();
    final sample = File('${temp.path}${Platform.pathSeparator}driver_sample.txt');
    await sample.writeAsString('driver-sample-content');
    final folder =
        Directory('${temp.path}${Platform.pathSeparator}driver_folder');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final child =
        File('${folder.path}${Platform.pathSeparator}child.bin');
    await child.writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7, 8]);

    final items = <DropItem>[
      DropItem(
        name: 'driver_sample.txt',
        path: sample.path,
        isDirectory: false,
        size: await sample.length(),
        mimeType: 'text/plain',
      ),
      DropItem(
        name: 'driver_folder',
        path: folder.path,
        isDirectory: true,
        size: 0,
        children: <DropItem>[
          DropItem(
            name: 'child.bin',
            path: child.path,
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
      'firstDroppedPath': ui?.firstDroppedPath,
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
