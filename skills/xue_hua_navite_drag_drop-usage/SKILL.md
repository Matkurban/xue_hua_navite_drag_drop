---
name: xue_hua_navite_drag_drop-usage
description: >-
  Use when the user is working with xue_hua_navite_drag_drop APIs to implement
  cross-platform file and folder drag-in (NativeDropRegion) or drag-out to the
  OS desktop/apps (NativeDraggable) across macOS, Windows, Linux, iOS, Android,
  and Web.
---

# XueHua Native Drag & Drop Usage

## Guidelines

* Wrap any target widget area with `NativeDropRegion` to receive files and folders dragged from the operating system (Finder, Explorer, File Manager, iPadOS/Android split-screen, or browser).
* Check `item.isDirectory` on each `DropItem` in `onPerformDrop` to distinguish folders from files; inspect `item.children` for recursive directory entries.
* Prefer `item.openRead()` over `item.readAsBytes()` when reading large files such as videos (`video/mp4`, `video/quicktime`) to stream chunks without exhausting memory.
* Wrap widgets with `NativeDraggable` to allow users to drag files or videos out of the Flutter app into the OS desktop or external folders.
* Use `DragOutItem.file(filePath: ...)` when the file already exists on local disk or cache; use `DragOutItem.asyncFile(...)` or `DragOutItem.memory(...)` when the file should only be materialized on demand upon drop.

## Examples

### Receiving files and folders dragged from the computer

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

class FileDropZone extends StatelessWidget {
  const FileDropZone({super.key});

  @override
  Widget build(BuildContext context) {
    return NativeDropRegion(
      onDragEnter: (NativeDragEvent event) {
        debugPrint('Cursor entered at ${event.localPosition}');
      },
      onPerformDrop: (NativeDropEvent event) async {
        for (final DropItem item in event.items) {
          if (item.isDirectory) {
            debugPrint('Folder: ${item.name} (${item.children.length} items)');
          } else {
            debugPrint('File: ${item.name}, size: ${item.size}, path: ${item.path}');
            await for (final chunk in item.openRead()) {
              // Process file or video stream in chunks.
              debugPrint('Read chunk of ${chunk.length} bytes');
            }
          }
        }
      },
      child: const SizedBox(
        width: 320,
        height: 200,
        child: Center(child: Text('Drop files or folders here')),
      ),
    );
  }
}
```

### Dragging local files or on-demand generated files out to the computer

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

class FileDragOutCard extends StatelessWidget {
  const FileDragOutCard({super.key, this.localVideoPath});

  final String? localVideoPath;

  @override
  Widget build(BuildContext context) {
    return NativeDraggable(
      itemsBuilder: () async {
        return <DragOutItem>[
          if (localVideoPath != null)
            DragOutItem.file(
              filePath: localVideoPath!,
              fileName: 'exported_video.mp4',
            ),
          DragOutItem.memory(
            fileName: 'metadata.json',
            mimeType: 'application/json',
            bytesProvider: () async =>
                Uint8List.fromList(utf8.encode('{"exported": true}')),
          ),
        ];
      },
      onDragCompleted: (bool success) {
        debugPrint('Drag-out completed: $success');
      },
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Drag me to the desktop'),
        ),
      ),
    );
  }
}
```
