#include "flutter_window.h"

#include "system_audio_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

constexpr ULONG_PTR kFolioLaunchArgsCopyDataId = 0x464F4C49;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::vector<std::string> launch_arguments)
    : project_(project), launch_arguments_(std::move(launch_arguments)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  system_audio_plugin_ = std::make_unique<SystemAudioPlugin>(
      flutter_controller_->engine()->messenger());

    launch_arguments_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "folio/windows_launch_args",
      &flutter::StandardMethodCodec::GetInstance());
    launch_arguments_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getInitialLaunchArguments") {
          flutter::EncodableList out;
          for (const auto& arg : launch_arguments_) {
            out.push_back(flutter::EncodableValue(arg));
          }
          result->Success(flutter::EncodableValue(out));
          return;
        }
        result->NotImplemented();
      });
  FlushPendingLaunchArguments();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  launch_arguments_channel_ = nullptr;
  system_audio_plugin_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      auto* data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (data == nullptr || data->dwData != kFolioLaunchArgsCopyDataId ||
          data->lpData == nullptr || data->cbData < sizeof(wchar_t)) {
        return FALSE;
      }

      const auto* raw_argument = static_cast<const wchar_t*>(data->lpData);
      const std::string argument = Utf8FromUtf16(raw_argument);
      if (!argument.empty()) {
        DispatchLaunchArgument(argument);
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::DispatchLaunchArgument(const std::string& argument) {
  if (!launch_arguments_channel_) {
    pending_launch_arguments_.push_back(argument);
    return;
  }

  flutter::EncodableList arguments;
  arguments.push_back(flutter::EncodableValue(argument));
  launch_arguments_channel_->InvokeMethod(
      "launchArguments",
      std::make_unique<flutter::EncodableValue>(arguments));
}

void FlutterWindow::FlushPendingLaunchArguments() {
  if (!launch_arguments_channel_ || pending_launch_arguments_.empty()) {
    return;
  }

  for (const auto& argument : pending_launch_arguments_) {
    DispatchLaunchArgument(argument);
  }
  pending_launch_arguments_.clear();
}
