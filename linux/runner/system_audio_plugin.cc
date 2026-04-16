#include "system_audio_plugin.h"

#include <cstring>

namespace {

struct SystemAudioPlugin {
  FlMethodChannel* method_channel = nullptr;
  FlEventChannel* event_channel = nullptr;
  gboolean listening = FALSE;
};

static SystemAudioPlugin* g_plugin = nullptr;

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "startCapture") == 0) {
    // Stub seguro: registra el canal pero por ahora no hace captura PipeWire.
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(FALSE)));
  } else if (strcmp(method, "stopCapture") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send system audio method response: %s", error->message);
  }
}

static FlMethodErrorResponse* on_listen_cb(FlEventChannel* channel,
                                           FlValue* args,
                                           gpointer user_data) {
  auto* self = static_cast<SystemAudioPlugin*>(user_data);
  self->listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* on_cancel_cb(FlEventChannel* channel,
                                           FlValue* args,
                                           gpointer user_data) {
  auto* self = static_cast<SystemAudioPlugin*>(user_data);
  self->listening = FALSE;
  return nullptr;
}

}  // namespace

void system_audio_plugin_register_with_messenger(FlBinaryMessenger* messenger) {
  if (g_plugin != nullptr) {
    return;
  }
  auto* self = new SystemAudioPlugin();
  g_plugin = self;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  self->method_channel = fl_method_channel_new(
      messenger, "folio/system_audio", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->method_channel, method_call_cb, self, nullptr);

  self->event_channel = fl_event_channel_new(
      messenger, "folio/system_audio_stream", FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->event_channel, on_listen_cb, on_cancel_cb, self, nullptr);
}
