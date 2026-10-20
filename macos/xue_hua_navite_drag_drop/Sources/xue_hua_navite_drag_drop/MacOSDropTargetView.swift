import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Transparent overlay view that intercepts macOS system drag-and-drop operations
/// while letting normal mouse clicks pass through to the underlying FlutterView.
final class MacOSDropTargetView: NSView {
  private weak var channel: FlutterMethodChannel?
  var currentDragOperation: NSDragOperation = .copy

  init(frame frameRect: NSRect, channel: FlutterMethodChannel) {
    self.channel = channel
    super.init(frame: frameRect)
    self.autoresizingMask = [.width, .height]
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // Allow normal mouse/trackpad events to pass through directly to FlutterView.
    return nil
  }

  private func convertToFlutterPoint(_ draggingInfo: NSDraggingInfo) -> NSPoint {
    let windowPoint = draggingInfo.draggingLocation
    let localPoint = convert(windowPoint, from: nil)
    // Flip Y coordinate from AppKit bottom-left origin to Flutter top-left origin.
    return NSPoint(x: localPoint.x, y: bounds.height - localPoint.y)
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let pt = convertToFlutterPoint(sender)
    channel?.invokeMethod("onDragEntered", arguments: ["x": pt.x, "y": pt.y])
    return currentDragOperation
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let pt = convertToFlutterPoint(sender)
    channel?.invokeMethod("onDragUpdated", arguments: ["x": pt.x, "y": pt.y])
    return currentDragOperation
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    channel?.invokeMethod("onDragExited", arguments: nil)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return currentDragOperation != []
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard currentDragOperation != [] else {
      return false
    }
    let pasteboard = sender.draggingPasteboard
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true
    ]
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
          !urls.isEmpty else {
      return false
    }

    let pt = convertToFlutterPoint(sender)
    let items = urls.map { Self.serializeURL($0, depth: 0) }
    channel?.invokeMethod("onPerformDrop", arguments: [
      "x": pt.x,
      "y": pt.y,
      "items": items
    ])
    return true
  }

  static func serializeURL(_ url: URL, depth: Int) -> [String: Any?] {
    let resourceKeys: Set<URLResourceKey> = [
      .nameKey,
      .isDirectoryKey,
      .fileSizeKey,
      .contentTypeKey
    ]
    let values = try? url.resourceValues(forKeys: resourceKeys)
    let isDirectory = values?.isDirectory ?? false
    let name = values?.name ?? url.lastPathComponent
    var size = values?.fileSize ?? 0
    let mimeType = values?.contentType?.preferredMIMEType

    var bookmarkBase64: String? = nil
    if depth == 0 {
      if let bookmarkData = try? url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      ) {
        bookmarkBase64 = bookmarkData.base64EncodedString()
      }
    }

    var children: [[String: Any?]] = []
    if isDirectory && depth < 3 {
      if let subUrls = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: Array(resourceKeys),
        options: [.skipsHiddenFiles]
      ) {
        children = subUrls.map { serializeURL($0, depth: depth + 1) }
        size = children.reduce(0) { sum, dict in
          sum + ((dict["size"] as? Int) ?? 0)
        }
      }
    }

    return [
      "name": name,
      "path": url.path,
      "uri": url.absoluteString,
      "isDirectory": isDirectory,
      "size": size,
      "mimeType": mimeType,
      "bookmark": bookmarkBase64,
      "children": children
    ]
  }
}
