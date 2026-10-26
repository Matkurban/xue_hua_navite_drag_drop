#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_

#include <windows.h>
#include <ole2.h>
#include <shellapi.h>
#include <shlobj.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace xue_hua_navite_drag_drop {

class WindowsDropTarget;

class XueHuaNaviteDragDropPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteDragDropPlugin();

  XueHuaNaviteDragDropPlugin(
      flutter::PluginRegistrarWindows *registrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

  virtual ~XueHuaNaviteDragDropPlugin();

  XueHuaNaviteDragDropPlugin(const XueHuaNaviteDragDropPlugin&) = delete;
  XueHuaNaviteDragDropPlugin& operator=(const XueHuaNaviteDragDropPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::MethodChannel<flutter::EncodableValue>* channel() const {
    return channel_.get();
  }

  HWND GetHwnd() const;
  DWORD current_drop_effect() const { return current_drop_effect_; }

 private:
  void EnsureDropTargetRegistered();
  void NotifyDragOutEnded(bool success);
  void StartDragOutWithPaths(const std::vector<std::wstring>& file_paths);

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  WindowsDropTarget *drop_target_ = nullptr;
  HWND registered_hwnd_ = nullptr;
  DWORD current_drop_effect_ = DROPEFFECT_COPY;
};

}  // namespace xue_hua_navite_drag_drop

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_DRAG_DROP_PLUGIN_H_
