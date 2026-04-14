#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>
#include <string>
#include <vector>

#include <flutter/method_channel.h>
#include "microsoft_store_plugin.h"
#include "system_audio_plugin.h"

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  FlutterWindow(const flutter::DartProject& project,
                std::vector<std::string> launch_arguments);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void DispatchLaunchArgument(const std::string& argument);
  void FlushPendingLaunchArguments();

  // The project to run.
  flutter::DartProject project_;
  std::vector<std::string> launch_arguments_;
  std::vector<std::string> pending_launch_arguments_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      launch_arguments_channel_;
  std::unique_ptr<SystemAudioPlugin> system_audio_plugin_;
  std::unique_ptr<FolioMicrosoftStorePlugin> microsoft_store_plugin_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
