#pragma once

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <atomic>

#include <windows.h>

/// MethodChannel `folio/system_media` + EventChannel `folio/system_media_events`.
///
/// Arquitectura (evitar freeze/crash del motor Flutter):
/// - **Nunca** ejecutar WinRT `.get()` en el hilo de UI / MethodChannel
///   (bombea el message loop y reentra Flutter → freeze / 0xC0000409).
/// - Todo GSMTC corre en un **worker MTA**.
/// - Solo el hilo de UI entrega `MethodResult` / `EventSink` (vía PostMessage).
class SystemMediaPlugin {
 public:
  SystemMediaPlugin(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~SystemMediaPlugin();

  static UINT DeferredUiWindowMessage();
  /// Alias de compatibilidad con [FlutterWindow::MessageHandler].
  static UINT DeferredInvokeWindowMessage();

  /// Llamar desde [FlutterWindow::MessageHandler] en el hilo de UI.
  void ProcessDeferredUi(LPARAM lparam) noexcept;
  /// Alias de compatibilidad.
  void ProcessDeferredInvoke(LPARAM lparam) noexcept;

 private:
  enum class MediaOp {
    kGetCurrent,
    kStartListening,
    kStopListening,
    kPlay,
    kPause,
    kSkipNext,
    kSkipPrevious,
    kSeek,
  };

  enum class UiDelivery {
    kMethodSuccessMap,
    kMethodSuccessNull,
    kMethodError,
    kEventMap,
  };

  struct WorkerJob {
    MediaOp op = MediaOp::kGetCurrent;
    int64_t position_ms = 0;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  };

  struct UiMessage {
    UiDelivery kind = UiDelivery::kMethodSuccessNull;
    flutter::EncodableMap map;
    std::string error_code;
    std::string error_message;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void EnqueueJob(std::unique_ptr<WorkerJob> job);
  void EnsureWorkerStarted();
  void WorkerMain();
  void StopWorker();

  // Solo worker thread:
  void WorkerEnsureManager();
  flutter::EncodableMap WorkerBuildSnapshot();
  void WorkerRunJob(WorkerJob& job);
  void PostUi(std::unique_ptr<UiMessage> msg);

  static UINT deferred_ui_message_id_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  HWND hwnd_ = nullptr;

  std::mutex jobs_mutex_;
  std::vector<std::unique_ptr<WorkerJob>> jobs_;
  HANDLE jobs_event_ = nullptr;
  std::atomic<bool> worker_stop_{false};
  std::atomic<bool> listening_{false};
  std::thread worker_;

  // Opaque WinRT (solo tocado por worker_).
  struct WinrtState;
  std::unique_ptr<WinrtState> winrt_;
};
