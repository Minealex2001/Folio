#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kFolioWindowClassName[] =
  L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kFolioSingleInstanceMutexName[] =
  L"Local\\FolioSingleInstanceMutex";
constexpr ULONG_PTR kFolioLaunchArgsCopyDataId = 0x464F4C49;

void RegisterFolioProtocol() {
  HKEY classes_key;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\folio", 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &classes_key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }

  const wchar_t* description = L"URL:Folio Protocol";
  ::RegSetValueExW(classes_key, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(description),
                   static_cast<DWORD>((wcslen(description) + 1) * sizeof(wchar_t)));
  const wchar_t* url_protocol = L"";
  ::RegSetValueExW(classes_key, L"URL Protocol", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(url_protocol),
                   static_cast<DWORD>(sizeof(wchar_t)));

  wchar_t exe_path[MAX_PATH];
  const DWORD len = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    ::RegCloseKey(classes_key);
    return;
  }

  std::wstring icon_value = std::wstring(L"\"") + exe_path + L"\",0";
  HKEY icon_key;
  if (::RegCreateKeyExW(classes_key, L"DefaultIcon", 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &icon_key,
                        nullptr) == ERROR_SUCCESS) {
    ::RegSetValueExW(icon_key, nullptr, 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(icon_value.c_str()),
                     static_cast<DWORD>((icon_value.size() + 1) * sizeof(wchar_t)));
    ::RegCloseKey(icon_key);
  }

  std::wstring command_value =
      std::wstring(L"\"") + exe_path + L"\" \"%1\"";
  HKEY command_key;
  if (::RegCreateKeyExW(classes_key, L"shell\\open\\command", 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &command_key,
                        nullptr) == ERROR_SUCCESS) {
    ::RegSetValueExW(command_key, nullptr, 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(command_value.c_str()),
                     static_cast<DWORD>((command_value.size() + 1) * sizeof(wchar_t)));
    ::RegCloseKey(command_key);
  }

  ::RegCloseKey(classes_key);
}

std::optional<std::wstring> GetFirstProtocolLaunchArgument() {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::nullopt;
  }

  std::optional<std::wstring> protocol_argument;
  for (int i = 1; i < argc; ++i) {
    if (_wcsnicmp(argv[i], L"folio://", 8) == 0) {
      protocol_argument = argv[i];
      break;
    }
  }

  ::LocalFree(argv);
  return protocol_argument;
}

HWND FindExistingWindow() {
  for (int attempt = 0; attempt < 50; ++attempt) {
    HWND window = ::FindWindowW(kFolioWindowClassName, L"folio");
    if (window != nullptr) {
      return window;
    }
    ::Sleep(100);
  }
  return nullptr;
}

void BringWindowToFront(HWND window) {
  if (window == nullptr) {
    return;
  }

  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  ::ShowWindow(window, SW_MAXIMIZE);
  ::BringWindowToTop(window);
  ::SetForegroundWindow(window);
}

void ForwardProtocolLaunchArgument(HWND window, const std::wstring& argument) {
  if (window == nullptr || argument.empty()) {
    return;
  }

  COPYDATASTRUCT payload;
  payload.dwData = kFolioLaunchArgsCopyDataId;
  payload.cbData =
      static_cast<DWORD>((argument.size() + 1) * sizeof(wchar_t));
  payload.lpData = const_cast<wchar_t*>(argument.c_str());

  DWORD_PTR ignored = 0;
  ::SendMessageTimeoutW(window, WM_COPYDATA, 0,
                        reinterpret_cast<LPARAM>(&payload),
                        SMTO_ABORTIFHUNG | SMTO_BLOCK, 3000, &ignored);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kFolioSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window = FindExistingWindow();
    const auto launch_argument = GetFirstProtocolLaunchArgument();
    if (existing_window != nullptr) {
      BringWindowToFront(existing_window);
      if (launch_argument.has_value()) {
        ForwardProtocolLaunchArgument(existing_window, launch_argument.value());
      }
    }
    ::CloseHandle(single_instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
  RegisterFolioProtocol();
  std::vector<std::string> launch_arguments = GetCommandLineArguments();

  FlutterWindow window(project, std::move(launch_arguments));
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"folio", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
