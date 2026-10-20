[English](README.md)

# xue_hua_navite_drag_drop

支持 **macOS / Windows / Linux / iOS (iPadOS) / Android / Web** 全 6 端的 Flutter 原生双向拖拽（Native Drag & Drop）插件。

## 核心特性

- **外部拖入（OS $\rightarrow$ Flutter）**：
  - 使用 `NativeDropRegion` 接收从电脑桌面、Finder、资源管理器、移动端分屏应用或浏览器外拖入的**任意类型文件（含视频、图片、文档）和文件夹**。
  - 支持多区域独立注册与坐标命中测试（Hit-Test），实时提供 `onDragEnter`、`onDragUpdate`、`onDragExit`、`onPerformDrop` 回调。
  - 统一封装 `DropItem`，支持读取文件名、路径、是否文件夹（`isDirectory`）、子文件树（`children`），并提供跨 6 端统一的 `readAsBytes()` 与流式读取 `openRead()`。
- **内部拖出保存到电脑（Flutter $\rightarrow$ OS）**：
  - 使用 `NativeDraggable` 将应用内的文件或视频直接拖出保存到电脑桌面或文件夹。
  - **模式 A（本地路径直接拖出）**：`DragOutItem.file(filePath: ...)`，直接将已存在的本地缓存文件/视频拖出到系统目录。
  - **模式 B（异步/内存按需生成文件）**：`DragOutItem.asyncFile(...)` 与 `DragOutItem.memory(...)`，在用户松手落盘时按需生成并写入目标文件（macOS 原生采用 `NSFilePromiseProvider`）。
  - 自动截取组件缩略图作为系统拖拽跟随预览图，也可传入自定义 PNG 字节预览图。
