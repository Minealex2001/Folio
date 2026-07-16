#include "smb_network_plugin.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <winnetwk.h>

#include <string>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int size =
      ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string utf8(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, utf8.data(), size, nullptr, nullptr);
  if (!utf8.empty() && utf8.back() == '\0') {
    utf8.pop_back();
  }
  return utf8;
}

std::wstring FormatWin32Error(DWORD code) {
  wchar_t* buffer = nullptr;
  const DWORD flags = FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                      FORMAT_MESSAGE_IGNORE_INSERTS;
  const DWORD len = ::FormatMessageW(flags, nullptr, code, 0,
                                     reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);
  if (len == 0 || buffer == nullptr) {
    return L"Error de red";
  }
  std::wstring message(buffer, len);
  ::LocalFree(buffer);
  while (!message.empty() &&
         (message.back() == L'\r' || message.back() == L'\n' || message.back() == L' ')) {
    message.pop_back();
  }
  return message;
}

std::wstring BuildUsername(const std::wstring& domain, const std::wstring& username) {
  if (domain.empty()) {
    return username;
  }
  return domain + L"\\" + username;
}

}  // namespace

SmbNetworkPlugin::SmbNetworkPlugin(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "folio/smb_network", &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

        if (method == "connectShare") {
          if (args == nullptr) {
            result->Error("invalid_args", "Missing arguments");
            return;
          }
          auto share_it = args->find(flutter::EncodableValue("shareRoot"));
          auto user_it = args->find(flutter::EncodableValue("username"));
          auto pass_it = args->find(flutter::EncodableValue("password"));
          auto domain_it = args->find(flutter::EncodableValue("domain"));
          if (share_it == args->end()) {
            result->Error("invalid_args", "shareRoot required");
            return;
          }

          const auto* share_root = std::get_if<std::string>(&share_it->second);
          if (share_root == nullptr || share_root->empty()) {
            result->Error("invalid_args", "shareRoot required");
            return;
          }

          std::string username;
          std::string password;
          std::string domain;
          if (user_it != args->end()) {
            if (const auto* v = std::get_if<std::string>(&user_it->second)) {
              username = *v;
            }
          }
          if (pass_it != args->end()) {
            if (const auto* v = std::get_if<std::string>(&pass_it->second)) {
              password = *v;
            }
          }
          if (domain_it != args->end()) {
            if (const auto* v = std::get_if<std::string>(&domain_it->second)) {
              domain = *v;
            }
          }

          const std::wstring share_w = Utf8ToWide(*share_root);
          const std::wstring user_w = BuildUsername(Utf8ToWide(domain), Utf8ToWide(username));
          const std::wstring pass_w = Utf8ToWide(password);

          NETRESOURCEW net_resource = {};
          net_resource.dwType = RESOURCETYPE_DISK;
          net_resource.lpRemoteName = const_cast<LPWSTR>(share_w.c_str());

          const DWORD dw_result = ::WNetAddConnection2W(
              &net_resource,
              pass_w.empty() ? nullptr : pass_w.c_str(),
              user_w.empty() ? nullptr : user_w.c_str(),
              0);

          flutter::EncodableMap response;
          response[flutter::EncodableValue("success")] =
              flutter::EncodableValue(dw_result == NO_ERROR);
          response[flutter::EncodableValue("errorCode")] =
              flutter::EncodableValue(static_cast<int32_t>(dw_result));
          if (dw_result != NO_ERROR) {
            response[flutter::EncodableValue("message")] =
                flutter::EncodableValue(WideToUtf8(FormatWin32Error(dw_result)));
          }
          result->Success(flutter::EncodableValue(response));
          return;
        }

        if (method == "disconnectShare") {
          if (args == nullptr) {
            result->Error("invalid_args", "Missing arguments");
            return;
          }
          auto share_it = args->find(flutter::EncodableValue("shareRoot"));
          if (share_it == args->end()) {
            result->Error("invalid_args", "shareRoot required");
            return;
          }
          const auto* share_root = std::get_if<std::string>(&share_it->second);
          if (share_root == nullptr || share_root->empty()) {
            result->Error("invalid_args", "shareRoot required");
            return;
          }
          const std::wstring share_w = Utf8ToWide(*share_root);
          const DWORD dw_result = ::WNetCancelConnection2W(
              share_w.c_str(), CONNECT_UPDATE_PROFILE, FALSE);
          flutter::EncodableMap response;
          response[flutter::EncodableValue("success")] =
              flutter::EncodableValue(dw_result == NO_ERROR);
          response[flutter::EncodableValue("errorCode")] =
              flutter::EncodableValue(static_cast<int32_t>(dw_result));
          result->Success(flutter::EncodableValue(response));
          return;
        }

        result->NotImplemented();
      });
}

SmbNetworkPlugin::~SmbNetworkPlugin() = default;
