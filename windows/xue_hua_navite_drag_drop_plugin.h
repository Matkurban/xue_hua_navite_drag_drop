#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_navite_drag_drop {

class XueHuaNaviteDragDropPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteDragDropPlugin();

  virtual ~XueHuaNaviteDragDropPlugin();

  // Disallow copy and assign.
  XueHuaNaviteDragDropPlugin(const XueHuaNaviteDragDropPlugin&) = delete;
  XueHuaNaviteDragDropPlugin& operator=(const XueHuaNaviteDragDropPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_navite_drag_drop

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_
