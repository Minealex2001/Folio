#include "system_media_plugin.h"

#include <cstring>

namespace {

struct SystemMediaPlugin {
  FlMethodChannel* method_channel = nullptr;
  FlEventChannel* event_channel = nullptr;
  gboolean listening = FALSE;
};

static SystemMediaPlugin* g_plugin = nullptr;

static FlValue* empty_snapshot_map() {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "title", fl_value_new_string(""));
  fl_value_set_string_take(map, "artist", fl_value_new_string(""));
  fl_value_set_string_take(map, "appId", fl_value_new_string(""));
  fl_value_set_string_take(map, "appName", fl_value_new_string(""));
  const uint8_t empty_art[1] = {0};
  fl_value_set_string_take(map, "albumArt",
                           fl_value_new_uint8_list(empty_art, 0));
  fl_value_set_string_take(map, "isPlaying", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "progressMs", fl_value_new_int(0));
  fl_value_set_string_take(map, "durationMs", fl_value_new_int(0));
  fl_value_set_string_take(map, "canPlay", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "canPause", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "canSkipNext", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "canSkipPrevious", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "canSeek", fl_value_new_bool(FALSE));
  return map;
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  (void)channel;
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "isSupported") == 0) {
    // Stub: MPRIS aún no implementado.
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(FALSE)));
  } else if (strcmp(method, "hasPermission") == 0) {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  } else if (strcmp(method, "openPermissionSettings") == 0 ||
             strcmp(method, "startListening") == 0 ||
             strcmp(method, "stopListening") == 0 ||
             strcmp(method, "play") == 0 ||
             strcmp(method, "pause") == 0 ||
             strcmp(method, "skipNext") == 0 ||
             strcmp(method, "skipPrevious") == 0 ||
             strcmp(method, "seek") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "getCurrent") == 0) {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(empty_snapshot_map()));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send system media method response: %s", error->message);
  }
}

static FlMethodErrorResponse* on_listen_cb(FlEventChannel* channel,
                                           FlValue* args,
                                           gpointer user_data) {
  (void)channel;
  (void)args;
  auto* self = static_cast<SystemMediaPlugin*>(user_data);
  self->listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* on_cancel_cb(FlEventChannel* channel,
                                           FlValue* args,
                                           gpointer user_data) {
  (void)channel;
  (void)args;
  auto* self = static_cast<SystemMediaPlugin*>(user_data);
  self->listening = FALSE;
  return nullptr;
}

}  // namespace

void system_media_plugin_register_with_messenger(FlBinaryMessenger* messenger) {
  if (g_plugin != nullptr) {
    return;
  }
  auto* self = new SystemMediaPlugin();
  g_plugin = self;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  self->method_channel = fl_method_channel_new(
      messenger, "folio/system_media", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->method_channel, method_call_cb, self, nullptr);

  self->event_channel = fl_event_channel_new(
      messenger, "folio/system_media_events", FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->event_channel, on_listen_cb, on_cancel_cb, self, nullptr);
}
