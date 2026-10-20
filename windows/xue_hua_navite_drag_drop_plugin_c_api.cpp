#include "include/xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_navite_drag_drop_plugin.h"

void XueHuaNaviteDragDropPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_navite_drag_drop::XueHuaNaviteDragDropPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
