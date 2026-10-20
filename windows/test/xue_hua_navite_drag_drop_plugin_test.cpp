#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "xue_hua_navite_drag_drop_plugin.h"

namespace xue_hua_navite_drag_drop {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(XueHuaNaviteDragDropPlugin, SetDropEffectUpdatesState) {
  XueHuaNaviteDragDropPlugin plugin;
  bool succeeded = false;
  EncodableMap args = {
      {EncodableValue("operation"), EncodableValue("none")},
  };
  plugin.HandleMethodCall(
      MethodCall("setDropEffect", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          [&succeeded](const EncodableValue*) {
            succeeded = true;
          },
          nullptr, nullptr));

  EXPECT_TRUE(succeeded);
  EXPECT_EQ(plugin.current_drop_effect(), static_cast<DWORD>(DROPEFFECT_NONE));
}

}  // namespace test
}  // namespace xue_hua_navite_drag_drop
