#include "system_media_plugin.h"

#include <flutter/event_stream_handler_functions.h>

#include <VersionHelpers.h>

#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <string>

#pragma comment(lib, "windowsapp.lib")

#pragma warning(push)
#pragma warning(disable : 4996)

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Media::Control;

namespace {

std::string Utf8FromHString(const winrt::hstring& h) {
  return winrt::to_string(h);
}

int64_t TimeSpanToMs(TimeSpan const& span) {
  return span.count() / 10000;
}

TimeSpan MsToTimeSpan(int64_t ms) {
  return TimeSpan{ms * 10000};
}

std::string BestEffortAppName(const winrt::hstring& aumid) {
  if (aumid.empty()) {
    return {};
  }
  try {
    auto info =
        Windows::ApplicationModel::AppInfo::GetFromAppUserModelId(aumid);
    if (info) {
      return Utf8FromHString(info.DisplayInfo().DisplayName());
    }
  } catch (...) {
  }
  const std::string raw = Utf8FromHString(aumid);
  const auto slash = raw.find_last_of("\\/");
  if (slash != std::string::npos && slash + 1 < raw.size()) {
    return raw.substr(slash + 1);
  }
  const auto bang = raw.find('!');
  if (bang != std::string::npos && bang > 0) {
    return raw.substr(0, bang);
  }
  return raw;
}

// GetCurrentSession() elige de forma poco fiable entre varias apps con
// sesión GSMTC registrada a la vez (Spotify, un navegador, un reproductor de
// música...), lo que se percibía como la línea de tiempo saltando
// adelante/atrás y la carátula parpadeando entre pistas distintas cada
// segundo. Preferimos: 1) una sesión que esté realmente reproduciendo, 2) la
// misma sesión que la última vez (aunque esté en pausa), 3) GetCurrentSession()
// como último recurso.
GlobalSystemMediaTransportControlsSession PickBestSession(
    GlobalSystemMediaTransportControlsSessionManager const& manager,
    std::wstring& last_aumid) {
  GlobalSystemMediaTransportControlsSession playing{nullptr};
  GlobalSystemMediaTransportControlsSession sticky{nullptr};
  GlobalSystemMediaTransportControlsSession fallback{nullptr};

  try {
    auto sessions = manager.GetSessions();
    for (uint32_t i = 0; i < sessions.Size(); ++i) {
      GlobalSystemMediaTransportControlsSession s{nullptr};
      try {
        s = sessions.GetAt(i);
      } catch (...) {
        continue;
      }
      if (!s) {
        continue;
      }
      if (!fallback) {
        fallback = s;
      }
      try {
        if (s.GetPlaybackInfo().PlaybackStatus() ==
            GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) {
          if (!playing) {
            playing = s;
          }
        }
      } catch (...) {
      }
      if (!last_aumid.empty() && !sticky) {
        try {
          if (std::wstring(s.SourceAppUserModelId()) == last_aumid) {
            sticky = s;
          }
        } catch (...) {
        }
      }
    }
  } catch (...) {
  }

  GlobalSystemMediaTransportControlsSession chosen{nullptr};
  if (playing) {
    chosen = playing;
  } else if (sticky) {
    chosen = sticky;
  } else {
    try {
      chosen = manager.GetCurrentSession();
    } catch (...) {
    }
    if (!chosen) {
      chosen = fallback;
    }
  }

  if (chosen) {
    try {
      last_aumid = std::wstring(chosen.SourceAppUserModelId());
    } catch (...) {
    }
  } else {
    last_aumid.clear();
  }
  return chosen;
}

flutter::EncodableMap EmptySnapshotMap() {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("title")] = flutter::EncodableValue("");
  map[flutter::EncodableValue("artist")] = flutter::EncodableValue("");
  map[flutter::EncodableValue("appId")] = flutter::EncodableValue("");
  map[flutter::EncodableValue("appName")] = flutter::EncodableValue("");
  map[flutter::EncodableValue("isPlaying")] = flutter::EncodableValue(false);
  map[flutter::EncodableValue("progressMs")] = flutter::EncodableValue(0);
  map[flutter::EncodableValue("durationMs")] = flutter::EncodableValue(0);
  map[flutter::EncodableValue("canPlay")] = flutter::EncodableValue(false);
  map[flutter::EncodableValue("canPause")] = flutter::EncodableValue(false);
  map[flutter::EncodableValue("canSkipNext")] = flutter::EncodableValue(false);
  map[flutter::EncodableValue("canSkipPrevious")] =
      flutter::EncodableValue(false);
  map[flutter::EncodableValue("canSeek")] = flutter::EncodableValue(false);
  return map;
}

}  // namespace

struct SystemMediaPlugin::WinrtState {
  GlobalSystemMediaTransportControlsSessionManager manager{nullptr};
  bool manager_ready = false;
  bool manager_failed = false;

  // Selección "sticky": GetCurrentSession() de Windows alterna de forma poco
  // fiable entre varias apps con sesión registrada (p. ej. Spotify, un
  // navegador y el reproductor de música a la vez), lo que se veía como la
  // línea de tiempo saltando adelante/atrás y la carátula parpadeando entre
  // pistas distintas. Nos quedamos con el AUMID de la última sesión elegida
  // y solo cambiamos si esa sesión desaparece o hay otra reproduciendo.
  std::wstring last_session_aumid;

  // Cache de carátula: evita releer y reenviar hasta 8 MB por cada poll de
  // 1s cuando la pista no ha cambiado.
  std::wstring art_cache_key;
  std::vector<uint8_t> art_cache_bytes;
};

UINT SystemMediaPlugin::deferred_ui_message_id_ = 0;

UINT SystemMediaPlugin::DeferredUiWindowMessage() {
  if (deferred_ui_message_id_ == 0) {
    deferred_ui_message_id_ =
        RegisterWindowMessageW(L"Folio_SystemMedia_DeferredUi_v2");
  }
  return deferred_ui_message_id_;
}

// Compat: flutter_window.cpp puede seguir usando el nombre antiguo.
UINT SystemMediaPlugin::DeferredInvokeWindowMessage() {
  return DeferredUiWindowMessage();
}

SystemMediaPlugin::SystemMediaPlugin(flutter::BinaryMessenger* messenger,
                                     HWND hwnd)
    : method_channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              "folio/system_media",
              &flutter::StandardMethodCodec::GetInstance())),
      event_channel_(
          std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
              messenger,
              "folio/system_media_events",
              &flutter::StandardMethodCodec::GetInstance())),
      hwnd_(hwnd),
      winrt_(std::make_unique<WinrtState>()) {
  DeferredUiWindowMessage();
  jobs_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* /*args*/,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     sink)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = std::move(sink);
            return nullptr;
          },
          [this](const flutter::EncodableValue* /*args*/)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = nullptr;
            return nullptr;
          });
  event_channel_->SetStreamHandler(std::move(handler));
}

SystemMediaPlugin::~SystemMediaPlugin() {
  StopWorker();
  event_sink_ = nullptr;
  if (jobs_event_) {
    CloseHandle(jobs_event_);
    jobs_event_ = nullptr;
  }
}

void SystemMediaPlugin::EnsureWorkerStarted() {
  if (worker_.joinable()) {
    return;
  }
  worker_stop_ = false;
  worker_ = std::thread([this]() { WorkerMain(); });
}

void SystemMediaPlugin::StopWorker() {
  worker_stop_ = true;
  listening_ = false;
  if (jobs_event_) {
    SetEvent(jobs_event_);
  }
  if (worker_.joinable()) {
    worker_.join();
  }
  std::lock_guard<std::mutex> lock(jobs_mutex_);
  for (auto& job : jobs_) {
    if (job && job->result) {
      // No tocar Flutter desde destructor/worker dying: descartar.
      job->result.reset();
    }
  }
  jobs_.clear();
}

void SystemMediaPlugin::EnqueueJob(std::unique_ptr<WorkerJob> job) {
  EnsureWorkerStarted();
  {
    std::lock_guard<std::mutex> lock(jobs_mutex_);
    jobs_.push_back(std::move(job));
  }
  if (jobs_event_) {
    SetEvent(jobs_event_);
  }
}

void SystemMediaPlugin::PostUi(std::unique_ptr<UiMessage> msg) {
  if (!hwnd_ || !IsWindow(hwnd_)) {
    return;
  }
  const UINT mid = DeferredUiWindowMessage();
  UiMessage* raw = msg.release();
  if (!PostMessageW(hwnd_, mid, 0, reinterpret_cast<LPARAM>(raw))) {
    delete raw;
  }
}

void SystemMediaPlugin::ProcessDeferredUi(LPARAM lparam) noexcept {
  std::unique_ptr<UiMessage> msg(reinterpret_cast<UiMessage*>(lparam));
  if (!msg) {
    return;
  }
  try {
    switch (msg->kind) {
      case UiDelivery::kMethodSuccessMap:
        if (msg->result) {
          msg->result->Success(flutter::EncodableValue(msg->map));
        }
        break;
      case UiDelivery::kMethodSuccessNull:
        if (msg->result) {
          // flutter::EncodableValue(nullptr) silently resolves to the
          // variant's `bool` alternative (nullptr_t -> bool is a valid
          // implicit conversion, and no alternative accepts nullptr_t
          // directly) instead of a real null/monostate value. That bogus
          // `false` reply does not properly complete the Dart-side
          // invokeMethod Future when delivered via this deferred path.
          // The default-constructed EncodableValue() is the real null.
          msg->result->Success(flutter::EncodableValue());
        }
        break;
      case UiDelivery::kMethodError:
        if (msg->result) {
          msg->result->Error(msg->error_code, msg->error_message, nullptr);
        }
        break;
      case UiDelivery::kEventMap:
        if (event_sink_ && listening_) {
          event_sink_->Success(flutter::EncodableValue(msg->map));
        }
        break;
    }
  } catch (...) {
  }
}

// Alias usado por flutter_window.cpp existente.
void SystemMediaPlugin::ProcessDeferredInvoke(LPARAM lparam) noexcept {
  ProcessDeferredUi(lparam);
}

void SystemMediaPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "isSupported") {
    result->Success(flutter::EncodableValue(IsWindows10OrGreater() != FALSE));
    return;
  }
  if (method == "hasPermission") {
    result->Success(flutter::EncodableValue(true));
    return;
  }
  if (method == "openPermissionSettings") {
    result->Success(flutter::EncodableValue());
    return;
  }

  if (!hwnd_ || !IsWindow(hwnd_)) {
    result->Error("system_media", "No top-level window handle.", nullptr);
    return;
  }

  auto job = std::make_unique<WorkerJob>();
  job->result = std::move(result);

  if (method == "getCurrent") {
    job->op = MediaOp::kGetCurrent;
  } else if (method == "startListening") {
    job->op = MediaOp::kStartListening;
  } else if (method == "stopListening") {
    job->op = MediaOp::kStopListening;
  } else if (method == "play") {
    job->op = MediaOp::kPlay;
  } else if (method == "pause") {
    job->op = MediaOp::kPause;
  } else if (method == "skipNext") {
    job->op = MediaOp::kSkipNext;
  } else if (method == "skipPrevious") {
    job->op = MediaOp::kSkipPrevious;
  } else if (method == "seek") {
    job->op = MediaOp::kSeek;
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("positionMs"));
      if (it != args->end()) {
        if (const auto* i = std::get_if<int32_t>(&it->second)) {
          job->position_ms = *i;
        } else if (const auto* i64 = std::get_if<int64_t>(&it->second)) {
          job->position_ms = *i64;
        }
      }
    }
  } else {
    job->result->NotImplemented();
    return;
  }

  EnqueueJob(std::move(job));
}

void SystemMediaPlugin::WorkerMain() {
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
  } catch (...) {
    // Ya inicializado u otro error: intentar seguir.
  }

  while (!worker_stop_) {
    // Polling de listening: 1s, o despertar por jobs.
    const DWORD wait_ms = listening_ ? 1000 : 5000;
    WaitForSingleObject(jobs_event_, wait_ms);

    if (worker_stop_) {
      break;
    }

    std::vector<std::unique_ptr<WorkerJob>> batch;
    {
      std::lock_guard<std::mutex> lock(jobs_mutex_);
      batch.swap(jobs_);
    }

    for (auto& job : batch) {
      if (!job) {
        continue;
      }
      WorkerRunJob(*job);
    }

    // Snapshot periódico mientras listening (sin eventos WinRT cross-thread).
    if (listening_ && !worker_stop_) {
      try {
        auto map = WorkerBuildSnapshot();
        auto msg = std::make_unique<UiMessage>();
        msg->kind = UiDelivery::kEventMap;
        msg->map = std::move(map);
        PostUi(std::move(msg));
      } catch (...) {
      }
    }
  }

  try {
    winrt_->manager = nullptr;
    winrt_->manager_ready = false;
  } catch (...) {
  }
}

void SystemMediaPlugin::WorkerEnsureManager() {
  if (winrt_->manager_failed) {
    return;
  }
  if (winrt_->manager_ready && winrt_->manager) {
    return;
  }
  try {
    winrt_->manager =
        GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
    winrt_->manager_ready = static_cast<bool>(winrt_->manager);
    if (!winrt_->manager_ready) {
      winrt_->manager_failed = true;
    }
  } catch (...) {
    winrt_->manager = nullptr;
    winrt_->manager_ready = false;
    winrt_->manager_failed = true;
  }
}

flutter::EncodableMap SystemMediaPlugin::WorkerBuildSnapshot() {
  WorkerEnsureManager();
  if (!winrt_->manager) {
    return EmptySnapshotMap();
  }

  GlobalSystemMediaTransportControlsSession session{nullptr};
  try {
    session = PickBestSession(winrt_->manager, winrt_->last_session_aumid);
  } catch (...) {
    // El manager en sí está roto (no solo "sin sesión activa", que devuelve
    // null sin lanzar): no reintentar cada segundo contra el mismo fallo.
    winrt_->manager = nullptr;
    winrt_->manager_ready = false;
    winrt_->manager_failed = true;
    return EmptySnapshotMap();
  }
  if (!session) {
    return EmptySnapshotMap();
  }

  flutter::EncodableMap map = EmptySnapshotMap();

  try {
    const winrt::hstring aumid = session.SourceAppUserModelId();
    map[flutter::EncodableValue("appId")] =
        flutter::EncodableValue(Utf8FromHString(aumid));
    map[flutter::EncodableValue("appName")] =
        flutter::EncodableValue(BestEffortAppName(aumid));
  } catch (...) {
  }

  try {
    auto props = session.TryGetMediaPropertiesAsync().get();
    if (props) {
      const std::wstring title = props.Title().c_str();
      const std::wstring artist = props.Artist().c_str();
      map[flutter::EncodableValue("title")] =
          flutter::EncodableValue(Utf8FromHString(props.Title()));
      map[flutter::EncodableValue("artist")] =
          flutter::EncodableValue(Utf8FromHString(props.Artist()));

      // Carátula: aislada en su propio try/catch. Históricamente
      // OpenReadAsync podía provocar un access violation en shcore.dll
      // (Win11); ahora este archivo compila con /EHa, así que catch(...)
      // sí lo captura y degrada en vez de crashear el proceso.
      //
      // Cacheada por pista (aumid+título+artista): sin esto, cada poll de
      // 1s releía y reenviaba hasta 8 MB de imagen idéntica, lo cual se veía
      // como la carátula parpadeando en la UI en cada tick.
      try {
        const std::wstring art_key =
            winrt_->last_session_aumid + L"|" + title + L"|" + artist;
        if (art_key == winrt_->art_cache_key &&
            !winrt_->art_cache_bytes.empty()) {
          map[flutter::EncodableValue("albumArt")] =
              flutter::EncodableValue(winrt_->art_cache_bytes);
        } else {
          auto thumb_ref = props.Thumbnail();
          if (thumb_ref) {
            auto stream = thumb_ref.OpenReadAsync().get();
            if (stream) {
              const uint64_t size64 = stream.Size();
              constexpr uint64_t kMaxThumbnailBytes = 8ull * 1024 * 1024;
              if (size64 > 0 && size64 <= kMaxThumbnailBytes) {
                const uint32_t size = static_cast<uint32_t>(size64);
                winrt::Windows::Storage::Streams::DataReader reader(stream);
                reader.LoadAsync(size).get();
                std::vector<uint8_t> bytes(size);
                reader.ReadBytes(winrt::array_view<uint8_t>(bytes));
                winrt_->art_cache_key = art_key;
                winrt_->art_cache_bytes = bytes;
                map[flutter::EncodableValue("albumArt")] =
                    flutter::EncodableValue(std::move(bytes));
              }
            }
          }
        }
      } catch (...) {
        // Sin carátula: degradar en silencio, no propagar al catch externo.
      }
    }
  } catch (...) {
  }

  try {
    auto info = session.GetPlaybackInfo();
    if (info) {
      const auto status = info.PlaybackStatus();
      map[flutter::EncodableValue("isPlaying")] = flutter::EncodableValue(
          status == GlobalSystemMediaTransportControlsSessionPlaybackStatus::
                        Playing);
      auto controls = info.Controls();
      if (controls) {
        map[flutter::EncodableValue("canPlay")] =
            flutter::EncodableValue(controls.IsPlayEnabled());
        map[flutter::EncodableValue("canPause")] =
            flutter::EncodableValue(controls.IsPauseEnabled());
        map[flutter::EncodableValue("canSkipNext")] =
            flutter::EncodableValue(controls.IsNextEnabled());
        map[flutter::EncodableValue("canSkipPrevious")] =
            flutter::EncodableValue(controls.IsPreviousEnabled());
        map[flutter::EncodableValue("canSeek")] =
            flutter::EncodableValue(controls.IsPlaybackPositionEnabled());
      }
    }
  } catch (...) {
  }

  try {
    auto timeline = session.GetTimelineProperties();
    if (timeline) {
      map[flutter::EncodableValue("progressMs")] =
          flutter::EncodableValue(static_cast<int32_t>(
              std::max<int64_t>(0, TimeSpanToMs(timeline.Position()))));
      const int64_t end_ms = TimeSpanToMs(timeline.EndTime());
      const int64_t start_ms = TimeSpanToMs(timeline.StartTime());
      int64_t duration_ms = end_ms - start_ms;
      if (duration_ms <= 0) {
        duration_ms = TimeSpanToMs(timeline.MaxSeekTime());
      }
      map[flutter::EncodableValue("durationMs")] = flutter::EncodableValue(
          static_cast<int32_t>(std::max<int64_t>(0, duration_ms)));
    }
  } catch (...) {
  }

  return map;
}

void SystemMediaPlugin::WorkerRunJob(WorkerJob& job) {
  auto reply_null = [&]() {
    auto msg = std::make_unique<UiMessage>();
    msg->kind = UiDelivery::kMethodSuccessNull;
    msg->result = std::move(job.result);
    PostUi(std::move(msg));
  };
  auto reply_map = [&](flutter::EncodableMap map) {
    auto msg = std::make_unique<UiMessage>();
    msg->kind = UiDelivery::kMethodSuccessMap;
    msg->map = std::move(map);
    msg->result = std::move(job.result);
    PostUi(std::move(msg));
  };
  auto reply_error = [&](const std::string& code, const std::string& message) {
    auto msg = std::make_unique<UiMessage>();
    msg->kind = UiDelivery::kMethodError;
    msg->error_code = code;
    msg->error_message = message;
    msg->result = std::move(job.result);
    PostUi(std::move(msg));
  };

  try {
    switch (job.op) {
      case MediaOp::kGetCurrent:
        reply_map(WorkerBuildSnapshot());
        return;
      case MediaOp::kStartListening:
        listening_ = true;
        WorkerEnsureManager();
        reply_null();
        // Primer evento inmediato.
        {
          auto msg = std::make_unique<UiMessage>();
          msg->kind = UiDelivery::kEventMap;
          msg->map = WorkerBuildSnapshot();
          PostUi(std::move(msg));
        }
        return;
      case MediaOp::kStopListening:
        listening_ = false;
        reply_null();
        return;
      case MediaOp::kPlay: {
        WorkerEnsureManager();
        if (winrt_->manager) {
          auto session = winrt_->manager.GetCurrentSession();
          if (session) {
            session.TryPlayAsync().get();
          }
        }
        reply_null();
        return;
      }
      case MediaOp::kPause: {
        WorkerEnsureManager();
        if (winrt_->manager) {
          auto session = winrt_->manager.GetCurrentSession();
          if (session) {
            session.TryPauseAsync().get();
          }
        }
        reply_null();
        return;
      }
      case MediaOp::kSkipNext: {
        WorkerEnsureManager();
        if (winrt_->manager) {
          auto session = winrt_->manager.GetCurrentSession();
          if (session) {
            session.TrySkipNextAsync().get();
          }
        }
        reply_null();
        return;
      }
      case MediaOp::kSkipPrevious: {
        WorkerEnsureManager();
        if (winrt_->manager) {
          auto session = winrt_->manager.GetCurrentSession();
          if (session) {
            session.TrySkipPreviousAsync().get();
          }
        }
        reply_null();
        return;
      }
      case MediaOp::kSeek: {
        WorkerEnsureManager();
        if (winrt_->manager) {
          auto session = winrt_->manager.GetCurrentSession();
          if (session) {
            session
                .TryChangePlaybackPositionAsync(
                    MsToTimeSpan(job.position_ms).count())
                .get();
          }
        }
        reply_null();
        return;
      }
    }
  } catch (const winrt::hresult_error& e) {
    reply_error("system_media_hresult", Utf8FromHString(e.message()));
  } catch (const std::exception& e) {
    reply_error("system_media", e.what());
  } catch (...) {
    reply_error("system_media", "Unexpected native error in system media.");
  }
}

#pragma warning(pop)
