#ifndef RUNNER_SYSTEM_AUDIO_PLUGIN_H_
#define RUNNER_SYSTEM_AUDIO_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

void system_audio_plugin_register_with_messenger(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // RUNNER_SYSTEM_AUDIO_PLUGIN_H_
