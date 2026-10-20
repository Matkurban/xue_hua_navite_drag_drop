#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_plugin.h"
#include "xue_hua_navite_drag_drop_plugin_private.h"

namespace xue_hua_navite_drag_drop {
namespace test {

TEST(XueHuaNaviteDragDropPlugin, PluginTypeRegistered) {
  GType type = xue_hua_navite_drag_drop_plugin_get_type();
  EXPECT_NE(type, G_TYPE_INVALID);
}

}  // namespace test
}  // namespace xue_hua_navite_drag_drop
