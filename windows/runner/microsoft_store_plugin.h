#pragma once

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include <windows.h>

/// MethodChannel `folio/microsoft_store` — debe vivir tanto como [FlutterWindow].
///
/// Las APIs de `Windows.Services.Store` van en el hilo STA de la ventana y
/// nunca en el callback directo del MethodChannel (ni siquiera si es el mismo
/// hilo): WinRT puede reentrar el bucle de mensajes y corromper el motor.
class FolioMicrosoftStorePlugin {
 public:
  FolioMicrosoftStorePlugin(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~FolioMicrosoftStorePlugin() = default;

  /// Mensaje Win32 para ejecutar trabajo aplazado en el hilo de la ventana.
  static UINT DeferredInvokeWindowMessage();

  /// Llamar desde [FlutterWindow::MessageHandler] en el hilo de UI.
  void ProcessDeferredInvoke(LPARAM lparam) noexcept;

 private:
  enum class StoreOp { kGetLicense, kGetCollectionsId, kRequestPurchase };

  struct PendingInvoke {
    StoreOp op;
    std::string store_id;
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void DispatchStoreOp(StoreOp op,
                       const std::string& store_id,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                           result) noexcept;

  static bool PostStoreWorkToUiThread(
      HWND hwnd,
      std::unique_ptr<PendingInvoke> pending);

  static UINT deferred_message_id_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND hwnd_;
};
