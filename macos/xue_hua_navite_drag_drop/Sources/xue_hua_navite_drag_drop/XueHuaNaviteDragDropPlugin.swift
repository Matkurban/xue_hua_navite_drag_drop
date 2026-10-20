import Cocoa
import FlutterMacOS

public class XueHuaNaviteDragDropPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private let channel: FlutterMethodChannel
  private var dropTargetView: MacOSDropTargetView?
  private lazy var dragOutSession = MacOSDragOutSession(channel: channel)

  init(registrar: FlutterPluginRegistrar, channel: FlutterMethodChannel) {
    self.registrar = registrar
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "xue_hua_navite_drag_drop",
      binaryMessenger: registrar.messenger
    )
    let instance = XueHuaNaviteDragDropPlugin(registrar: registrar, channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func resolveFlutterView() -> NSView? {
    if let view = registrar.view {
      return view
    }
    return NSApp.mainWindow?.contentView ?? NSApp.windows.first?.contentView
  }

  private func attachDropTargetIfNeeded() {
    guard dropTargetView == nil, let hostView = resolveFlutterView() else {
      return
    }
    let overlay = MacOSDropTargetView(frame: hostView.bounds, channel: channel)
    hostView.addSubview(overlay, positioned: .above, relativeTo: nil)
    dropTargetView = overlay
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

    case "initDragDrop":
      DispatchQueue.main.async { [weak self] in
        self?.attachDropTargetIfNeeded()
        result(nil)
      }

    case "setDropEffect":
      if let args = call.arguments as? [String: Any],
         let op = args["operation"] as? String {
        switch op {
        case "none":
          dropTargetView?.currentDragOperation = []
        case "move":
          dropTargetView?.currentDragOperation = .move
        case "link":
          dropTargetView?.currentDragOperation = .link
        default:
          dropTargetView?.currentDragOperation = .copy
        }
      }
      result(nil)

    case "startDragOut":
      attachDropTargetIfNeeded()
      guard let hostView = resolveFlutterView(),
            let args = call.arguments as? [String: Any],
            let items = args["items"] as? [[String: Any]] else {
        result(false)
        return
      }
      let x = (args["x"] as? Double) ?? 0.0
      let y = (args["y"] as? Double) ?? 0.0
      let started = dragOutSession.startDragSession(
        in: hostView,
        items: items,
        flutterPosition: NSPoint(x: x, y: y)
      )
      result(started)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
