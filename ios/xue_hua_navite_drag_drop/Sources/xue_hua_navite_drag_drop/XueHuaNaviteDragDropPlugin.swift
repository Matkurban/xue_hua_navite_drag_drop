import Flutter
import UIKit
import UniformTypeIdentifiers

public class XueHuaNaviteDragDropPlugin: NSObject, FlutterPlugin, UIDropInteractionDelegate, UIDragInteractionDelegate {
  private let channel: FlutterMethodChannel?
  private weak var hostView: UIView?
  private var interactionsAttached = false
  private var currentProposalOperation: UIDropOperation = .copy
  private var pendingDragOutItems: [[String: Any]] = []

  public override init() {
    self.channel = nil
    super.init()
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "xue_hua_navite_drag_drop",
      binaryMessenger: registrar.messenger()
    )
    let instance = XueHuaNaviteDragDropPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func resolveRootView() -> UIView? {
    if let view = hostView {
      return view
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
         let rootVC = keyWindow.rootViewController {
        hostView = rootVC.view
        return rootVC.view
      }
    }
    return nil
  }

  private func attachInteractionsIfNeeded() {
    guard !interactionsAttached, let view = resolveRootView() else {
      return
    }
    let dropInteraction = UIDropInteraction(delegate: self)
    view.addInteraction(dropInteraction)

    let dragInteraction = UIDragInteraction(delegate: self)
    dragInteraction.isEnabled = true
    view.addInteraction(dragInteraction)
    interactionsAttached = true
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initDragDrop":
      DispatchQueue.main.async { [weak self] in
        self?.attachInteractionsIfNeeded()
        result(nil)
      }

    case "setDropEffect":
      if let args = call.arguments as? [String: Any],
         let op = args["operation"] as? String {
        switch op {
        case "none":
          currentProposalOperation = .forbidden
        case "move":
          currentProposalOperation = .move
        default:
          currentProposalOperation = .copy
        }
      }
      result(nil)

    case "startDragOut":
      attachInteractionsIfNeeded()
      if let args = call.arguments as? [String: Any],
         let items = args["items"] as? [[String: Any]],
         !items.isEmpty {
        pendingDragOutItems = items
        result(true)
      } else {
        result(false)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - UIDropInteractionDelegate

  public func dropInteraction(
    _ interaction: UIDropInteraction,
    canHandle session: UIDropSession
  ) -> Bool {
    return session.hasItemsConforming(toTypeIdentifiers: [
      UTType.item.identifier,
      UTType.folder.identifier,
      UTType.content.identifier
    ])
  }

  public func dropInteraction(
    _ interaction: UIDropInteraction,
    sessionDidEnter session: UIDropSession
  ) {
    guard let view = interaction.view else { return }
    let pt = session.location(in: view)
    channel?.invokeMethod("onDragEntered", arguments: ["x": pt.x, "y": pt.y])
  }

  public func dropInteraction(
    _ interaction: UIDropInteraction,
    sessionDidUpdate session: UIDropSession
  ) -> UIDropProposal {
    if let view = interaction.view {
      let pt = session.location(in: view)
      channel?.invokeMethod("onDragUpdated", arguments: ["x": pt.x, "y": pt.y])
    }
    return UIDropProposal(operation: currentProposalOperation)
  }

  public func dropInteraction(
    _ interaction: UIDropInteraction,
    sessionDidExit session: UIDropSession
  ) {
    channel?.invokeMethod("onDragExited", arguments: nil)
  }

  public func dropInteraction(
    _ interaction: UIDropInteraction,
    performDrop session: UIDropSession
  ) {
    guard let view = interaction.view else { return }
    let pt = session.location(in: view)
    let group = DispatchGroup()
    let lock = NSLock()
    var serializedItems: [[String: Any?]] = []

    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("xue_hua_drop_\(Int(Date().timeIntervalSince1970))", isDirectory: true)
    try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    for dragItem in session.items {
      let provider = dragItem.itemProvider
      let typeId = provider.registeredTypeIdentifiers.first ?? UTType.item.identifier
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
        defer { group.leave() }
        guard let sourceUrl = url else { return }
        let destUrl = tempRoot.appendingPathComponent(sourceUrl.lastPathComponent)
        try? FileManager.default.removeItem(at: destUrl)
        do {
          try FileManager.default.copyItem(at: sourceUrl, to: destUrl)
          let serialized = Self.serializeURL(destUrl, depth: 0)
          lock.lock()
          serializedItems.append(serialized)
          lock.unlock()
        } catch {
          // Ignore unreadable item.
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      self?.channel?.invokeMethod("onPerformDrop", arguments: [
        "x": pt.x,
        "y": pt.y,
        "items": serializedItems
      ])
    }
  }

  private static func serializeURL(_ url: URL, depth: Int) -> [String: Any?] {
    let keys: Set<URLResourceKey> = [.nameKey, .isDirectoryKey, .fileSizeKey, .contentTypeKey]
    let values = try? url.resourceValues(forKeys: keys)
    let isDirectory = values?.isDirectory ?? false
    let name = values?.name ?? url.lastPathComponent
    var size = values?.fileSize ?? 0
    let mimeType = values?.contentType?.preferredMIMEType

    var children: [[String: Any?]] = []
    if isDirectory && depth < 3 {
      if let subUrls = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles]
      ) {
        children = subUrls.map { serializeURL($0, depth: depth + 1) }
        size = children.reduce(0) { sum, dict in sum + ((dict["size"] as? Int) ?? 0) }
      }
    }

    return [
      "name": name,
      "path": url.path,
      "uri": url.absoluteString,
      "isDirectory": isDirectory,
      "size": size,
      "mimeType": mimeType,
      "children": children
    ]
  }

  // MARK: - UIDragInteractionDelegate

  public func dragInteraction(
    _ interaction: UIDragInteraction,
    itemsForBeginning session: UIDragSession
  ) -> [UIDragItem] {
    guard !pendingDragOutItems.isEmpty else {
      return []
    }
    let itemsToDrag = pendingDragOutItems
    pendingDragOutItems = []

    var uiDragItems: [UIDragItem] = []
    for (idx, item) in itemsToDrag.enumerated() {
      let fileName = (item["fileName"] as? String) ?? "file_\(idx)"
      let filePath = item["filePath"] as? String
      let isAsync = (item["isAsync"] as? Bool) ?? (filePath == nil || filePath!.isEmpty)
      let itemId = (item["id"] as? String) ?? "id_\(idx)"

      if !isAsync, let path = filePath, !path.isEmpty {
        let fileUrl = URL(fileURLWithPath: path)
        if let provider = NSItemProvider(contentsOf: fileUrl) {
          provider.suggestedName = fileName
          uiDragItems.append(UIDragItem(itemProvider: provider))
        }
      } else {
        let ext = (fileName as NSString).pathExtension
        let utType = UTType(filenameExtension: ext) ?? .data
        let provider = NSItemProvider()
        provider.suggestedName = fileName
        provider.registerFileRepresentation(
          forTypeIdentifier: utType.identifier,
          fileOptions: [],
          visibility: .all
        ) { [weak self] completion in
          let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
          DispatchQueue.main.async {
            guard let channel = self?.channel else {
              completion(nil, false, nil)
              return
            }
            channel.invokeMethod(
              "onRequestAsyncFileWrite",
              arguments: [
                "id": itemId,
                "destinationPath": tempUrl.path
              ]
            ) { response in
              if let ok = response as? Bool, ok {
                completion(tempUrl, false, nil)
              } else {
                completion(nil, false, nil)
              }
            }
          }
          return nil
        }
        uiDragItems.append(UIDragItem(itemProvider: provider))
      }
    }
    return uiDragItems
  }

  public func dragInteraction(
    _ interaction: UIDragInteraction,
    session: UIDragSession,
    didEndWith operation: UIDropOperation
  ) {
    let success = operation != .cancel && operation != .forbidden
    channel?.invokeMethod("onDragOutEnded", arguments: ["success": success])
  }
}
