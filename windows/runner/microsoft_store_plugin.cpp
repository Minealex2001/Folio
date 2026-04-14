#include "microsoft_store_plugin.h"

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <windows.h>

#include <string>

#pragma comment(lib, "windowsapp.lib")

#pragma warning(push)
#pragma warning(disable : 4996)

using namespace winrt;
using namespace Windows::Services::Store;

namespace {

std::string Utf8FromHString(const winrt::hstring& h) {
  return winrt::to_string(h);
}

}  // namespace

UINT FolioMicrosoftStorePlugin::deferred_message_id_ = 0;

UINT FolioMicrosoftStorePlugin::DeferredInvokeWindowMessage() {
  if (deferred_message_id_ == 0) {
    deferred_message_id_ =
        RegisterWindowMessageW(L"Folio_MicrosoftStore_DeferredInvoke_v1");
  }
  return deferred_message_id_;
}

FolioMicrosoftStorePlugin::FolioMicrosoftStorePlugin(
    flutter::BinaryMessenger* messenger,
    HWND hwnd)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger,
          "folio/microsoft_store",
          &flutter::StandardMethodCodec::GetInstance())),
      hwnd_(hwnd) {
  DeferredInvokeWindowMessage();
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

bool FolioMicrosoftStorePlugin::PostStoreWorkToUiThread(
    HWND hwnd,
    std::unique_ptr<PendingInvoke> pending) {
  const UINT msg = DeferredInvokeWindowMessage();
  PendingInvoke* raw = pending.release();
  if (!PostMessageW(hwnd, msg, 0, reinterpret_cast<LPARAM>(raw))) {
    std::unique_ptr<PendingInvoke> reclaim(raw);
    if (reclaim && reclaim->result) {
      reclaim->result->Error(
          "microsoft_store",
          "PostMessage to UI thread failed (Microsoft Store).",
          nullptr);
    }
    return false;
  }
  return true;
}

void FolioMicrosoftStorePlugin::ProcessDeferredInvoke(LPARAM lparam) noexcept {
  std::unique_ptr<PendingInvoke> pending(
      reinterpret_cast<PendingInvoke*>(lparam));
  if (!pending || !pending->result) {
    return;
  }
  DispatchStoreOp(pending->op, pending->store_id, std::move(pending->result));
}

void FolioMicrosoftStorePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!hwnd_ || !IsWindow(hwnd_)) {
    result->Error("microsoft_store", "No top-level window handle.", nullptr);
    return;
  }

  StoreOp op;
  std::string store_id;

  if (call.method_name() == "getLicenseStatus") {
    op = StoreOp::kGetLicense;
  } else if (call.method_name() == "getCustomerCollectionsId") {
    op = StoreOp::kGetCollectionsId;
  } else if (call.method_name() == "requestPurchase") {
    op = StoreOp::kRequestPurchase;
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("storeProductId"));
      if (it != args->end()) {
        const auto* s = std::get_if<std::string>(&it->second);
        if (s) {
          store_id = *s;
        }
      }
    }
    if (store_id.empty()) {
      result->Error("invalid_argument", "storeProductId required");
      return;
    }
  } else {
    result->NotImplemented();
    return;
  }

  // Nunca ejecutar WinRT aquí, ni aunque este hilo sea el de la ventana: el
  // callback del MethodChannel puede estar en medio del reparto de mensajes
  // de Flutter; WinRT con .get() puede bombear el bucle y reentrar, dejando
  // el motor en estado corrupto (cierre unos segundos después).
  auto pending = std::make_unique<PendingInvoke>();
  pending->op = op;
  pending->store_id = std::move(store_id);
  pending->result = std::move(result);
  FolioMicrosoftStorePlugin::PostStoreWorkToUiThread(hwnd_, std::move(pending));
}

void FolioMicrosoftStorePlugin::DispatchStoreOp(
    StoreOp op,
    const std::string& store_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) noexcept {
  try {
    if (op == StoreOp::kGetLicense) {
      StoreContext context = StoreContext::GetDefault();
      StoreAppLicense license = context.GetAppLicenseAsync().get();
      flutter::EncodableMap map;
      map[flutter::EncodableValue("licenseActive")] =
          flutter::EncodableValue(license.IsActive());
      map[flutter::EncodableValue("isTrial")] =
          flutter::EncodableValue(license.IsTrial());
      result->Success(flutter::EncodableValue(map));
      return;
    }

    if (op == StoreOp::kGetCollectionsId) {
      StoreContext context = StoreContext::GetDefault();
      winrt::hstring id =
          context.GetCustomerCollectionsIdAsync(L"", L"").get();
      result->Success(flutter::EncodableValue(Utf8FromHString(id)));
      return;
    }

    if (op == StoreOp::kRequestPurchase) {
      StoreContext context = StoreContext::GetDefault();
      StorePurchaseResult purchase_result =
          context.RequestPurchaseAsync(winrt::to_hstring(store_id)).get();
      StorePurchaseStatus status = purchase_result.Status();
      flutter::EncodableMap map;
      map[flutter::EncodableValue("status")] =
          flutter::EncodableValue(static_cast<int>(status));
      std::string status_name = "unknown";
      switch (status) {
        case StorePurchaseStatus::Succeeded:
          status_name = "succeeded";
          break;
        case StorePurchaseStatus::AlreadyPurchased:
          status_name = "alreadyPurchased";
          break;
        case StorePurchaseStatus::NotPurchased:
          status_name = "notPurchased";
          break;
        case StorePurchaseStatus::NetworkError:
          status_name = "networkError";
          break;
        case StorePurchaseStatus::ServerError:
          status_name = "serverError";
          break;
        default:
          break;
      }
      map[flutter::EncodableValue("statusName")] =
          flutter::EncodableValue(status_name);
      result->Success(flutter::EncodableValue(map));
      return;
    }

    result->NotImplemented();
  } catch (const winrt::hresult_error& e) {
    result->Error("microsoft_store_hresult", Utf8FromHString(e.message()),
                  nullptr);
  } catch (const std::exception& e) {
    result->Error("microsoft_store", e.what(), nullptr);
  } catch (...) {
    result->Error(
        "microsoft_store",
        "Unexpected native error in Microsoft Store plugin.",
        nullptr);
  }
}

#pragma warning(pop)
