import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Context associated with an `NSFilePromiseProvider` for async file generation on macOS.
private final class AsyncPromiseContext {
  let id: String
  let fileName: String

  init(id: String, fileName: String) {
    self.id = id
    self.fileName = fileName
  }
}

/// Manages outbound drag sessions (`NSDraggingSource` + `NSFilePromiseProviderDelegate`) on macOS.
final class MacOSDragOutSession: NSObject, NSDraggingSource, NSFilePromiseProviderDelegate {
  private weak var channel: FlutterMethodChannel?
  private let workQueue: OperationQueue = {
    let q = OperationQueue()
    q.qualityOfService = .userInitiated
    return q
  }()

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  func startDragSession(
    in view: NSView,
    items: [[String: Any]],
    flutterPosition: NSPoint
  ) -> Bool {
    guard !items.isEmpty else {
      return false
    }

    let appKitPoint = NSPoint(x: flutterPosition.x, y: view.bounds.height - flutterPosition.y)
    var draggingItems: [NSDraggingItem] = []

    for (index, item) in items.enumerated() {
      let fileName = (item["fileName"] as? String) ?? "file_\(index)"
      let filePath = item["filePath"] as? String
      let isAsync = (item["isAsync"] as? Bool) ?? (filePath == nil || filePath!.isEmpty)
      let itemId = (item["id"] as? String) ?? "id_\(index)"

      // Mode A: only accept non-empty paths that currently exist on disk.
      // Missing/empty Mode A paths are skipped (mirrors Windows/Linux).
      let pasteboardWriter: NSPasteboardWriting
      if !isAsync {
        guard let path = filePath, !path.isEmpty,
              FileManager.default.fileExists(atPath: path) else {
          continue
        }
        let fileURL = URL(fileURLWithPath: path)
        pasteboardWriter = fileURL as NSURL
      } else {
        let ext = (fileName as NSString).pathExtension
        let utType = UTType(filenameExtension: ext) ?? .data
        let provider = NSFilePromiseProvider(fileType: utType.identifier, delegate: self)
        provider.userInfo = AsyncPromiseContext(id: itemId, fileName: fileName)
        pasteboardWriter = provider
      }

      let dragItem = NSDraggingItem(pasteboardWriter: pasteboardWriter)
      let previewImage = Self.resolvePreviewImage(item: item, fileName: fileName, filePath: filePath)
      let imageSize = previewImage.size.width > 0 ? previewImage.size : NSSize(width: 64, height: 64)
      let offset = CGFloat(draggingItems.count * 8)
      let dragFrame = NSRect(
        x: appKitPoint.x - imageSize.width / 2 + offset,
        y: appKitPoint.y - imageSize.height / 2 - offset,
        width: imageSize.width,
        height: imageSize.height
      )
      dragItem.setDraggingFrame(dragFrame, contents: previewImage)
      draggingItems.append(dragItem)
    }

    // Nothing valid to drag (e.g. only missing Mode A files).
    guard !draggingItems.isEmpty else {
      return false
    }

    let currentEvent = NSApp.currentEvent
    let windowPoint = view.convert(appKitPoint, to: nil)
    let dragEvent = NSEvent.mouseEvent(
      with: .leftMouseDragged,
      location: windowPoint,
      modifierFlags: currentEvent?.modifierFlags ?? [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: view.window?.windowNumber ?? 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1.0
    ) ?? currentEvent

    guard let eventToUse = dragEvent else {
      return false
    }

    view.beginDraggingSession(with: draggingItems, event: eventToUse, source: self)
    return true
  }

  private static func resolvePreviewImage(
    item: [String: Any],
    fileName: String,
    filePath: String?
  ) -> NSImage {
    if let typedData = item["previewImage"] as? FlutterStandardTypedData,
       let image = NSImage(data: typedData.data) {
      let maxSide: CGFloat = 120.0
      if image.size.width > maxSide || image.size.height > maxSide {
        let ratio = min(maxSide / image.size.width, maxSide / image.size.height)
        image.size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
      }
      return image
    }
    if let path = filePath, FileManager.default.fileExists(atPath: path) {
      let icon = NSWorkspace.shared.icon(forFile: path)
      icon.size = NSSize(width: 64, height: 64)
      return icon
    }
    let ext = (fileName as NSString).pathExtension
    let utType = UTType(filenameExtension: ext) ?? .data
    let icon = NSWorkspace.shared.icon(for: utType)
    icon.size = NSSize(width: 64, height: 64)
    return icon
  }

  // MARK: - NSDraggingSource

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    return context == .outsideApplication ? [.copy] : [.copy, .move]
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    let success = operation != []
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onDragOutEnded", arguments: ["success": success])
    }
  }

  // MARK: - NSFilePromiseProviderDelegate

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    fileNameForType fileType: String
  ) -> String {
    if let ctx = filePromiseProvider.userInfo as? AsyncPromiseContext {
      return ctx.fileName
    }
    return "ExportedFile"
  }

  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    return workQueue
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    writePromiseTo url: URL,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let ctx = filePromiseProvider.userInfo as? AsyncPromiseContext else {
      completionHandler(
        NSError(domain: "xue_hua_navite_drag_drop", code: -1, userInfo: [
          NSLocalizedDescriptionKey: "Missing promise context"
        ])
      )
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let channel = self?.channel else {
        completionHandler(
          NSError(domain: "xue_hua_navite_drag_drop", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "Channel unavailable"
          ])
        )
        return
      }
      channel.invokeMethod(
        "onRequestAsyncFileWrite",
        arguments: [
          "id": ctx.id,
          "destinationPath": url.path
        ]
      ) { response in
        if let ok = response as? Bool, ok {
          completionHandler(nil)
        } else {
          completionHandler(
            NSError(domain: "xue_hua_navite_drag_drop", code: -3, userInfo: [
              NSLocalizedDescriptionKey: "Failed to write promised file"
            ])
          )
        }
      }
    }
  }
}
