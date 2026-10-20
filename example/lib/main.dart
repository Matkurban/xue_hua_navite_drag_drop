import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isHoveringDropZone = false;
  Offset? _hoverPosition;
  final List<DropItem> _droppedItems = <DropItem>[];
  String _dragOutStatus = '等待拖出操作...';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final firstDroppedFile = _droppedItems
        .where((e) => !e.isDirectory && e.path != null)
        .firstOrNull;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('XueHua 6端原生拖拽演示')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 左侧：外部文件与文件夹拖入区域
              Expanded(
                flex: 3,
                child: NativeDropRegion(
                  onDragEnter: (event) {
                    setState(() {
                      _isHoveringDropZone = true;
                      _hoverPosition = event.localPosition;
                    });
                  },
                  onDragUpdate: (event) {
                    setState(() {
                      _hoverPosition = event.localPosition;
                    });
                  },
                  onDragExit: () {
                    setState(() {
                      _isHoveringDropZone = false;
                      _hoverPosition = null;
                    });
                  },
                  onPerformDrop: (event) {
                    setState(() {
                      _isHoveringDropZone = false;
                      _hoverPosition = null;
                      _droppedItems
                        ..clear()
                        ..addAll(event.items);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _isHoveringDropZone
                          ? Colors.indigo.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isHoveringDropZone
                            ? Colors.indigo
                            : Colors.grey.shade400,
                        width: _isHoveringDropZone ? 2.5 : 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              _isHoveringDropZone
                                  ? Icons.file_download
                                  : Icons.folder_open,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '1. 外部拖入区域（支持任意类型文件与文件夹）',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_hoverPosition != null)
                              Text(
                                '坐标: (${_hoverPosition!.dx.toStringAsFixed(0)}, ${_hoverPosition!.dy.toStringAsFixed(0)})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.indigo,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _droppedItems.isEmpty
                              ? const Center(
                                  child: Text(
                                    '请从电脑桌面/资源管理器拖拽任意文件、视频或文件夹到此区域',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _droppedItems.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = _droppedItems[index];
                                    return ListTile(
                                      leading: Icon(
                                        item.isDirectory
                                            ? Icons.folder
                                            : Icons.insert_drive_file,
                                        color: item.isDirectory
                                            ? Colors.amber.shade700
                                            : Colors.indigo,
                                      ),
                                      title: Text(item.name),
                                      subtitle: Text(
                                        '${item.isDirectory ? "文件夹 (${item.children.length} 项)" : "文件"} · '
                                        '${_formatBytes(item.size)}\n'
                                        '路径: ${item.path ?? item.uri ?? "Web 内存对象"}',
                                      ),
                                      isThreeLine: true,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 右侧：拖出文件到电脑桌面区域
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        '2. 内部拖出到电脑（双模式）',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '状态: $_dragOutStatus',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 模式 B：异步/内存按需生成文件拖出
                      NativeDraggable(
                        onDragStarted: () {
                          setState(() {
                            _dragOutStatus = '正在向外拖拽虚拟生成文件...';
                          });
                        },
                        onDragCompleted: (success) {
                          setState(() {
                            _dragOutStatus = success
                                ? '异步文件拖出保存成功！'
                                : '拖出已取消或未落盘';
                          });
                        },
                        itemsBuilder: () async {
                          final content = utf8.encode(
                            '由 XueHuaNaviteDragDrop 动态导出的文件内容\n'
                            '导出时间: ${DateTime.now().toIso8601String()}\n',
                          );
                          return <DragOutItem>[
                            DragOutItem.memory(
                              fileName: 'xue_hua_exported_note.txt',
                              mimeType: 'text/plain',
                              bytesProvider: () async =>
                                  Uint8List.fromList(content),
                            ),
                          ];
                        },
                        child: const Card(
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.bolt, color: Colors.deepOrange),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '按住我拖到桌面\n（模式B：异步/内存按需生成 .txt 文件）',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 模式 A：已知本地文件路径直接拖出
                      NativeDraggable(
                        enabled: firstDroppedFile != null,
                        onDragStarted: () {
                          setState(() {
                            _dragOutStatus =
                                '正在拖出本地文件: ${firstDroppedFile?.name}';
                          });
                        },
                        onDragCompleted: (success) {
                          setState(() {
                            _dragOutStatus = success ? '本地文件拖出成功！' : '本地文件拖出取消';
                          });
                        },
                        itemsBuilder: () async {
                          if (firstDroppedFile?.path == null) {
                            return const <DragOutItem>[];
                          }
                          return <DragOutItem>[
                            DragOutItem.file(
                              filePath: firstDroppedFile!.path!,
                              fileName: firstDroppedFile.name,
                            ),
                          ];
                        },
                        child: Card(
                          elevation: firstDroppedFile != null ? 2 : 0,
                          color: firstDroppedFile != null
                              ? null
                              : Colors.grey.shade200,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.video_file,
                                  color: firstDroppedFile != null
                                      ? Colors.teal
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    firstDroppedFile != null
                                        ? '按住我拖到桌面\n（模式A：直接拖出刚拖入的 ${firstDroppedFile.name}）'
                                        : '请先在左侧拖入任意本地文件/视频，即可在此测试本地路径直接拖出',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
