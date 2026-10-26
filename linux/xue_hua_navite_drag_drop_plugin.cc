#include "include/xue_hua_navite_drag_drop/xue_hua_navite_drag_drop_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>

#include <cstring>
#include <string>
#include <vector>

#include "xue_hua_navite_drag_drop_plugin_private.h"

#define XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_navite_drag_drop_plugin_get_type(), \
                              XueHuaNaviteDragDropPlugin))

struct _XueHuaNaviteDragDropPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  gboolean drop_registered;
  GdkDragAction current_action;
  GPtrArray* drag_out_uris;
};

G_DEFINE_TYPE(XueHuaNaviteDragDropPlugin, xue_hua_navite_drag_drop_plugin, g_object_get_type())

static FlValue* serialize_local_path(const gchar* path, int depth) {
  gboolean is_dir = g_file_test(path, G_FILE_TEST_IS_DIR);
  gint64 size = 0;
  g_autoptr(FlValue) children = fl_value_new_list();

  if (is_dir && depth < 3) {
    GDir* dir = g_dir_open(path, 0, nullptr);
    if (dir != nullptr) {
      const gchar* entry_name = nullptr;
      while ((entry_name = g_dir_read_name(dir)) != nullptr) {
        if (entry_name[0] == '.') continue;
        g_autofree gchar* child_path = g_build_filename(path, entry_name, nullptr);
        FlValue* child_val = serialize_local_path(child_path, depth + 1);
        FlValue* child_size = fl_value_lookup_string(child_val, "size");
        if (child_size != nullptr && fl_value_get_type(child_size) == FL_VALUE_TYPE_INT) {
          size += fl_value_get_int(child_size);
        }
        fl_value_append_take(children, child_val);
      }
      g_dir_close(dir);
    }
  } else if (!is_dir) {
    GStatBuf st;
    if (g_stat(path, &st) == 0) {
      size = static_cast<gint64>(st.st_size);
    }
  }

  g_autofree gchar* basename = g_path_get_basename(path);
  g_autofree gchar* uri = g_filename_to_uri(path, nullptr, nullptr);

  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "name", fl_value_new_string(basename ? basename : path));
  fl_value_set_string_take(map, "path", fl_value_new_string(path));
  fl_value_set_string_take(map, "uri", fl_value_new_string(uri ? uri : ""));
  fl_value_set_string_take(map, "isDirectory", fl_value_new_bool(is_dir));
  fl_value_set_string_take(map, "size", fl_value_new_int(size));
  fl_value_set_string(map, "children", children);
  return map;
}

static gboolean on_gtk_drag_motion(GtkWidget* widget, GdkDragContext* context,
                                   gint x, gint y, guint time, gpointer user_data) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "x", fl_value_new_float(static_cast<double>(x)));
  fl_value_set_string_take(args, "y", fl_value_new_float(static_cast<double>(y)));
  fl_method_channel_invoke_method(self->channel, "onDragUpdated", args, nullptr, nullptr, nullptr);
  gdk_drag_status(context, self->current_action, time);
  return TRUE;
}

static void on_gtk_drag_leave(GtkWidget* widget, GdkDragContext* context,
                              guint time, gpointer user_data) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  fl_method_channel_invoke_method(self->channel, "onDragExited", nullptr, nullptr, nullptr, nullptr);
}

static void on_gtk_drag_data_received(GtkWidget* widget, GdkDragContext* context,
                                      gint x, gint y, GtkSelectionData* data,
                                      guint info, guint time, gpointer user_data) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  if (self->current_action == static_cast<GdkDragAction>(0)) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }

  gchar** uris = gtk_selection_data_get_uris(data);
  g_autoptr(FlValue) items = fl_value_new_list();

  if (uris != nullptr) {
    for (int i = 0; uris[i] != nullptr; ++i) {
      g_autofree gchar* local_path = g_filename_from_uri(uris[i], nullptr, nullptr);
      if (local_path != nullptr) {
        fl_value_append_take(items, serialize_local_path(local_path, 0));
      }
    }
    g_strfreev(uris);
  }

  g_autoptr(FlValue) payload = fl_value_new_map();
  fl_value_set_string_take(payload, "x", fl_value_new_float(static_cast<double>(x)));
  fl_value_set_string_take(payload, "y", fl_value_new_float(static_cast<double>(y)));
  fl_value_set_string(payload, "items", items);

  fl_method_channel_invoke_method(self->channel, "onPerformDrop", payload, nullptr, nullptr, nullptr);
  gtk_drag_finish(context, TRUE, FALSE, time);
}

static void on_gtk_drag_data_get(GtkWidget* widget, GdkDragContext* context,
                                 GtkSelectionData* selection_data, guint info,
                                 guint time, gpointer user_data) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  if (self->drag_out_uris != nullptr && self->drag_out_uris->len > 0) {
    gtk_selection_data_set_uris(selection_data,
                                reinterpret_cast<gchar**>(self->drag_out_uris->pdata));
  }
}

static void on_gtk_drag_end(GtkWidget* widget, GdkDragContext* context, gpointer user_data) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  // Selected action is 0 when the user cancels the drag (e.g. Esc / drop outside).
  const GdkDragAction selected = gdk_drag_context_get_selected_action(context);
  const gboolean success = selected != static_cast<GdkDragAction>(0);
  g_autoptr(FlValue) payload = fl_value_new_map();
  fl_value_set_string_take(payload, "success", fl_value_new_bool(success));
  fl_method_channel_invoke_method(self->channel, "onDragOutEnded", payload, nullptr, nullptr, nullptr);
}

static void ensure_drop_target_registered(XueHuaNaviteDragDropPlugin* self) {
  if (self->drop_registered || self->registrar == nullptr) {
    return;
  }
  FlView* fl_view = fl_plugin_registrar_get_view(self->registrar);
  if (fl_view == nullptr) {
    return;
  }
  GtkWidget* widget = GTK_WIDGET(fl_view);
  GtkTargetEntry targets[] = {
      {const_cast<gchar*>("text/uri-list"), 0, 0},
  };
  gtk_drag_dest_set(widget, GTK_DEST_DEFAULT_ALL, targets, 1,
                    static_cast<GdkDragAction>(GDK_ACTION_COPY | GDK_ACTION_MOVE));

  g_signal_connect(widget, "drag-motion", G_CALLBACK(on_gtk_drag_motion), self);
  g_signal_connect(widget, "drag-leave", G_CALLBACK(on_gtk_drag_leave), self);
  g_signal_connect(widget, "drag-data-received", G_CALLBACK(on_gtk_drag_data_received), self);
  g_signal_connect(widget, "drag-data-get", G_CALLBACK(on_gtk_drag_data_get), self);
  g_signal_connect(widget, "drag-end", G_CALLBACK(on_gtk_drag_end), self);

  self->drop_registered = TRUE;
}

static void begin_gtk_drag_with_uris(XueHuaNaviteDragDropPlugin* self) {
  FlView* fl_view = fl_plugin_registrar_get_view(self->registrar);
  if (fl_view == nullptr) return;
  GtkWidget* widget = GTK_WIDGET(fl_view);

  GtkTargetEntry targets[] = {
      {const_cast<gchar*>("text/uri-list"), 0, 0},
  };
  GtkTargetList* target_list = gtk_target_list_new(targets, 1);
  GdkEvent* current_event = gtk_get_current_event();
  gtk_drag_begin_with_coordinates(
      widget, target_list,
      static_cast<GdkDragAction>(GDK_ACTION_COPY | GDK_ACTION_MOVE),
      1, current_event, -1, -1);
  if (current_event != nullptr) {
    gdk_event_free(current_event);
  }
  gtk_target_list_unref(target_list);
}

void xue_hua_navite_drag_drop_plugin_handle_method_call(
    XueHuaNaviteDragDropPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "initDragDrop") == 0) {
    ensure_drop_target_registered(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setDropEffect") == 0) {
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* op_val = fl_value_lookup_string(args, "operation");
      if (op_val != nullptr && fl_value_get_type(op_val) == FL_VALUE_TYPE_STRING) {
        const gchar* op = fl_value_get_string(op_val);
        if (g_strcmp0(op, "none") == 0) {
          self->current_action = static_cast<GdkDragAction>(0);
        } else if (g_strcmp0(op, "move") == 0) {
          self->current_action = GDK_ACTION_MOVE;
        } else if (g_strcmp0(op, "link") == 0) {
          self->current_action = GDK_ACTION_LINK;
        } else {
          self->current_action = GDK_ACTION_COPY;
        }
      }
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "startDragOut") == 0) {
    ensure_drop_target_registered(self);
    if (self->drag_out_uris != nullptr) {
      g_ptr_array_free(self->drag_out_uris, TRUE);
    }
    self->drag_out_uris = g_ptr_array_new_with_free_func(g_free);

    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* items = fl_value_lookup_string(args, "items");
      if (items != nullptr && fl_value_get_type(items) == FL_VALUE_TYPE_LIST) {
        size_t len = fl_value_get_length(items);
        for (size_t i = 0; i < len; ++i) {
          FlValue* item = fl_value_get_list_value(items, i);
          FlValue* path_val = fl_value_lookup_string(item, "filePath");
          if (path_val != nullptr && fl_value_get_type(path_val) == FL_VALUE_TYPE_STRING) {
            const gchar* path_str = fl_value_get_string(path_val);
            if (path_str != nullptr && strlen(path_str) > 0) {
              gchar* uri = g_filename_to_uri(path_str, nullptr, nullptr);
              if (uri != nullptr) {
                g_ptr_array_add(self->drag_out_uris, uri);
              }
            }
          }
        }
      }
    }
    g_ptr_array_add(self->drag_out_uris, nullptr);
    // pdata is a NULL-terminated URI list; len includes the trailing NULL entry.
    if (self->drag_out_uris->len <= 1) {
      g_autoptr(FlValue) res = fl_value_new_bool(FALSE);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
    } else {
      begin_gtk_drag_with_uris(self);
      g_autoptr(FlValue) res = fl_value_new_bool(TRUE);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_navite_drag_drop_plugin_dispose(GObject* object) {
  XueHuaNaviteDragDropPlugin* self = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(object);
  if (self->drag_out_uris != nullptr) {
    g_ptr_array_free(self->drag_out_uris, TRUE);
    self->drag_out_uris = nullptr;
  }
  g_clear_object(&self->channel);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(xue_hua_navite_drag_drop_plugin_parent_class)->dispose(object);
}

static void xue_hua_navite_drag_drop_plugin_class_init(XueHuaNaviteDragDropPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_navite_drag_drop_plugin_dispose;
}

static void xue_hua_navite_drag_drop_plugin_init(XueHuaNaviteDragDropPlugin* self) {
  self->drop_registered = FALSE;
  self->current_action = GDK_ACTION_COPY;
  self->drag_out_uris = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaNaviteDragDropPlugin* plugin = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(user_data);
  xue_hua_navite_drag_drop_plugin_handle_method_call(plugin, method_call);
}

void xue_hua_navite_drag_drop_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  XueHuaNaviteDragDropPlugin* plugin = XUE_HUA_NAVITE_DRAG_DROP_PLUGIN(
      g_object_new(xue_hua_navite_drag_drop_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "xue_hua_navite_drag_drop",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
