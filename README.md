[中文](README.zh-CN.md)

# xue_hua_navite_drag_drop

A Flutter native bidirectional drag-and-drop (Native Drag & Drop) plugin for all 6 platforms: **macOS / Windows / Linux / iOS (iPadOS) / Android / Web**.

## Features

- **Drag in from outside (OS $\rightarrow$ Flutter)**:
  - Use `NativeDropRegion` to receive **files of any type (including videos, images, and documents) and folders** dragged in from the desktop, Finder, File Explorer, split-screen mobile apps, or outside the browser.
  - Supports independently registered regions and coordinate hit-testing (Hit-Test), with live `onDragEnter`, `onDragUpdate`, `onDragExit`, and `onPerformDrop` callbacks.
  - Unified `DropItem` that can read the file name, path, whether it is a folder (`isDirectory`), and the child tree (`children`), and provides a consistent `readAsBytes()` and streaming `openRead()` across all 6 platforms.
- **Drag out to save on the computer (Flutter $\rightarrow$ OS)**:
  - Use `NativeDraggable` to drag in-app files or videos out and save them to the desktop or a folder.
  - **Mode A (drag out a local path directly)**: `DragOutItem.file(filePath: ...)`, drag an existing local cached file or video into a system directory.
  - **Mode B (generate a file asynchronously or from memory on demand)**: `DragOutItem.asyncFile(...)` and `DragOutItem.memory(...)` generate and write the target file when the user releases the drag (macOS uses `NSFilePromiseProvider` natively).
  - Automatically captures the widget thumbnail as the system drag-follow preview, or accepts a custom PNG byte preview.
