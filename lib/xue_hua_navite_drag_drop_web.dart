import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/models/drag_event.dart';
import 'src/models/drag_out_item.dart';
import 'src/models/drop_item.dart';
import 'xue_hua_navite_drag_drop_platform_interface.dart';

/// A web implementation of the XueHuaNaviteDragDropPlatform of the XueHuaNaviteDragDrop plugin.
class XueHuaNaviteDragDropWeb extends XueHuaNaviteDragDropPlatform {
  /// Constructs a XueHuaNaviteDragDropWeb.
  XueHuaNaviteDragDropWeb();

  static void registerWith(Registrar registrar) {
    XueHuaNaviteDragDropPlatform.instance = XueHuaNaviteDragDropWeb();
  }

  void Function(Offset globalPosition)? _onDragEntered;
  void Function(Offset globalPosition)? _onDragUpdated;
  void Function()? _onDragExited;
  Future<void> Function(Offset globalPosition, List<DropItem> items)?
      _onPerformDrop;
  void Function(bool success)? _onDragOutEnded;

  bool _listenersAttached = false;
  DropOperation _currentOperation = DropOperation.copy;

  @override
  void registerCallbackHandler({
    required void Function(Offset globalPosition) onDragEntered,
    required void Function(Offset globalPosition) onDragUpdated,
    required void Function() onDragExited,
    required Future<void> Function(Offset globalPosition, List<DropItem> items)
        onPerformDrop,
    required Future<bool> Function(String itemId, String destinationPath)
        onRequestAsyncFileWrite,
    required void Function(bool success) onDragOutEnded,
  }) {
    _onDragEntered = onDragEntered;
    _onDragUpdated = onDragUpdated;
    _onDragExited = onDragExited;
    _onPerformDrop = onPerformDrop;
    _onDragOutEnded = onDragOutEnded;
  }

  @override
  Future<void> initDragDrop() async {
    if (_listenersAttached) {
      return;
    }
    _listenersAttached = true;

    web.window.addEventListener(
      'dragenter',
      ((web.DragEvent event) {
        event.preventDefault();
        _onDragEntered?.call(
          Offset(event.clientX.toDouble(), event.clientY.toDouble()),
        );
      }).toJS,
    );

    web.window.addEventListener(
      'dragover',
      ((web.DragEvent event) {
        event.preventDefault();
        final pos = Offset(event.clientX.toDouble(), event.clientY.toDouble());
        _onDragUpdated?.call(pos);
        final dt = event.dataTransfer;
        if (dt != null) {
          dt.dropEffect = _currentOperation == DropOperation.none
              ? 'none'
              : _currentOperation.name;
        }
      }).toJS,
    );

    web.window.addEventListener(
      'dragleave',
      ((web.DragEvent event) {
        if (event.relatedTarget == null) {
          _onDragExited?.call();
        }
      }).toJS,
    );

    web.window.addEventListener(
      'drop',
      ((web.DragEvent event) {
        event.preventDefault();
        final pos = Offset(event.clientX.toDouble(), event.clientY.toDouble());
        _extractDroppedItems(event.dataTransfer).then((items) {
          _onPerformDrop?.call(pos, items);
        });
      }).toJS,
    );
  }

  @override
  Future<void> setDropEffect(DropOperation operation) async {
    _currentOperation = operation;
  }

  @override
  Future<bool> startDragOut({
    required List<DragOutItem> items,
    Offset? globalPosition,
  }) async {
    if (items.isEmpty) {
      return false;
    }
    try {
      for (final item in items) {
        Uint8List? bytes;
        if (item.bytesProvider != null) {
          bytes = await item.bytesProvider!();
        }
        final String downloadUrl;
        if (bytes != null) {
          final jsArray = <JSAny>[bytes.toJS].toJS;
          final blob = web.Blob(
            jsArray,
            web.BlobPropertyBag(
              type: item.mimeType ?? 'application/octet-stream',
            ),
          );
          downloadUrl = web.URL.createObjectURL(blob);
        } else if (item.filePath != null && item.filePath!.isNotEmpty) {
          downloadUrl = item.filePath!;
        } else {
          continue;
        }

        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = downloadUrl;
        anchor.download = item.fileName;
        anchor.style.display = 'none';
        web.document.body?.appendChild(anchor);
        anchor.click();
        anchor.remove();

        if (bytes != null) {
          Future<void>.delayed(const Duration(seconds: 10), () {
            web.URL.revokeObjectURL(downloadUrl);
          });
        }
      }
      _onDragOutEnded?.call(true);
      return true;
    } catch (_) {
      _onDragOutEnded?.call(false);
      return false;
    }
  }

  Future<List<DropItem>> _extractDroppedItems(
    web.DataTransfer? dataTransfer,
  ) async {
    if (dataTransfer == null) {
      return const <DropItem>[];
    }
    final results = <DropItem>[];
    final itemsList = dataTransfer.items;

    final entries = <JSObject>[];
    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList.getProperty<web.DataTransferItem?>(i.toJS);
      if (item != null && item.kind == 'file') {
        if (item.has('webkitGetAsEntry')) {
          final entry = item.callMethod<JSObject?>('webkitGetAsEntry'.toJS);
          if (entry != null) {
            entries.add(entry);
          }
        }
      }
    }

    if (entries.isNotEmpty) {
      for (final entry in entries) {
        final parsed = await _readWebkitEntry(entry);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    }

    final files = dataTransfer.files;
    for (int i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file != null) {
        results.add(
          DropItem(
            name: file.name,
            path: file.name,
            isDirectory: false,
            size: file.size,
            mimeType: file.type.isNotEmpty ? file.type : null,
            webFile: file,
          ),
        );
      }
    }
    return results;
  }

  Future<DropItem?> _readWebkitEntry(JSObject entry) async {
    final isFile =
        entry.getProperty<JSBoolean?>('isFile'.toJS)?.toDart ?? false;
    final isDirectory =
        entry.getProperty<JSBoolean?>('isDirectory'.toJS)?.toDart ?? false;
    final name =
        entry.getProperty<JSString?>('name'.toJS)?.toDart ?? 'unnamed';
    final fullPath =
        entry.getProperty<JSString?>('fullPath'.toJS)?.toDart ?? name;

    if (isFile) {
      final completer = Completer<DropItem?>();
      final successCb = ((web.File file) {
        completer.complete(
          DropItem(
            name: file.name,
            path: fullPath,
            isDirectory: false,
            size: file.size,
            mimeType: file.type.isNotEmpty ? file.type : null,
            webFile: file,
          ),
        );
      }).toJS;
      final errorCb = ((JSAny? _) {
        completer.complete(null);
      }).toJS;
      entry.callMethod<JSAny?>('file'.toJS, successCb, errorCb);
      return completer.future;
    } else if (isDirectory) {
      final reader = entry.callMethod<JSObject>('createReader'.toJS);
      final children = <DropItem>[];
      while (true) {
        final batch = await _readEntryBatch(reader);
        if (batch.isEmpty) {
          break;
        }
        for (final childEntry in batch) {
          final childItem = await _readWebkitEntry(childEntry);
          if (childItem != null) {
            children.add(childItem);
          }
        }
      }
      final totalSize = children.fold<int>(0, (sum, item) => sum + item.size);
      return DropItem(
        name: name,
        path: fullPath,
        isDirectory: true,
        size: totalSize,
        children: children,
      );
    }
    return null;
  }

  Future<List<JSObject>> _readEntryBatch(JSObject directoryReader) {
    final completer = Completer<List<JSObject>>();
    final successCb = ((JSArray<JSObject> entries) {
      completer.complete(entries.toDart);
    }).toJS;
    final errorCb = ((JSAny? _) {
      completer.complete(const <JSObject>[]);
    }).toJS;
    directoryReader.callMethod<JSAny?>('readEntries'.toJS, successCb, errorCb);
    return completer.future;
  }
}
