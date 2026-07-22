#include "system_audio_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <avrt.h>         // AvSetMmThreadCharacteristics
#include <functiondiscoverykeys_devpkey.h>
#include <ksmedia.h>

#include <cassert>
#include <cstring>
#include <string>
#include <vector>

#pragma comment(lib, "avrt.lib")
#pragma comment(lib, "ole32.lib")

namespace {

// Resample / convert a WASAPI float32 or int16 frame buffer to Int16LE 16kHz mono.
// Returns the converted bytes.
std::vector<uint8_t> ConvertToInt16Mono16k(
    const BYTE* src,
    UINT32 num_frames,
    const WAVEFORMATEX* wfx) {
  const UINT32 src_sample_rate = wfx->nSamplesPerSec;
  const UINT16 channels = wfx->nChannels;
  const bool is_float =
      wfx->wFormatTag == WAVE_FORMAT_IEEE_FLOAT ||
      (wfx->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
       IsEqualGUID(reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(wfx)->SubFormat,
             KSDATAFORMAT_SUBTYPE_IEEE_FLOAT));

  // Step 1 — convert to float mono at source sample rate.
  std::vector<float> mono(num_frames);
  if (is_float) {
    const float* f = reinterpret_cast<const float*>(src);
    for (UINT32 i = 0; i < num_frames; i++) {
      float sum = 0.f;
      for (UINT16 c = 0; c < channels; c++) sum += f[i * channels + c];
      mono[i] = sum / channels;
    }
  } else {
    // Assume 16-bit PCM
    const int16_t* s = reinterpret_cast<const int16_t*>(src);
    for (UINT32 i = 0; i < num_frames; i++) {
      int32_t sum = 0;
      for (UINT16 c = 0; c < channels; c++) sum += s[i * channels + c];
      mono[i] = static_cast<float>(sum / channels) / 32768.f;
    }
  }

  // Step 2 — resample to 16 kHz (simple linear interpolation).
  const UINT32 target_rate = 16000;
  const double ratio = static_cast<double>(src_sample_rate) / target_rate;
  const UINT32 out_frames =
      static_cast<UINT32>(static_cast<double>(num_frames) / ratio);

  std::vector<uint8_t> out(out_frames * sizeof(int16_t));
  int16_t* dst = reinterpret_cast<int16_t*>(out.data());
  for (UINT32 i = 0; i < out_frames; i++) {
    double pos = i * ratio;
    UINT32 idx = static_cast<UINT32>(pos);
    double frac = pos - idx;
    float s0 = mono[std::min(idx, num_frames - 1)];
    float s1 = mono[std::min(idx + 1, num_frames - 1)];
    float sample = static_cast<float>(s0 + frac * (s1 - s0));
    // Clamp to [-1, 1] before scaling
    if (sample > 1.f) sample = 1.f;
    if (sample < -1.f) sample = -1.f;
    dst[i] = static_cast<int16_t>(sample * 32767.f);
  }
  return out;
}

std::string WideToUtf8(const std::wstring& ws) {
  if (ws.empty()) return std::string();
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, ws.c_str(), static_cast<int>(ws.size()), nullptr, 0, nullptr, nullptr);
  if (size_needed <= 0) return std::string();
  std::string out(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), static_cast<int>(ws.size()),
                      out.data(), size_needed, nullptr, nullptr);
  return out;
}

std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(
      CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), nullptr, 0);
  if (size_needed <= 0) return std::wstring();
  std::wstring out(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                      out.data(), size_needed);
  return out;
}

IMMDevice* FindRenderEndpointById(IMMDeviceEnumerator* enumerator,
                                  const std::string& preferred_id) {
  if (!enumerator) return nullptr;
  if (preferred_id.empty()) {
    IMMDevice* fallback = nullptr;
    if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &fallback))) {
      return fallback;
    }
    return nullptr;
  }

  const std::wstring wanted = Utf8ToWide(preferred_id);
  if (wanted.empty()) return nullptr;

  IMMDeviceCollection* collection = nullptr;
  HRESULT hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
  if (FAILED(hr) || !collection) return nullptr;

  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; i++) {
    IMMDevice* dev = nullptr;
    if (FAILED(collection->Item(i, &dev)) || !dev) continue;
    LPWSTR dev_id = nullptr;
    if (SUCCEEDED(dev->GetId(&dev_id)) && dev_id != nullptr) {
      const bool match = (wanted == dev_id);
      CoTaskMemFree(dev_id);
      if (match) {
        collection->Release();
        return dev;
      }
    }
    dev->Release();
  }

  collection->Release();
  return nullptr;
}

flutter::EncodableList EnumerateRenderDevices() {
  flutter::EncodableList out;
  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(&enumerator));
  if (FAILED(hr) || !enumerator) return out;

  IMMDeviceCollection* collection = nullptr;
  hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
  if (FAILED(hr) || !collection) {
    enumerator->Release();
    return out;
  }

  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; i++) {
    IMMDevice* dev = nullptr;
    if (FAILED(collection->Item(i, &dev)) || !dev) continue;

    std::string id;
    std::string label;

    LPWSTR dev_id = nullptr;
    if (SUCCEEDED(dev->GetId(&dev_id)) && dev_id != nullptr) {
      id = WideToUtf8(dev_id);
      CoTaskMemFree(dev_id);
    }

    IPropertyStore* props = nullptr;
    if (SUCCEEDED(dev->OpenPropertyStore(STGM_READ, &props)) && props != nullptr) {
      PROPVARIANT value;
      PropVariantInit(&value);
      if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &value)) &&
          value.vt == VT_LPWSTR && value.pwszVal != nullptr) {
        label = WideToUtf8(value.pwszVal);
      }
      PropVariantClear(&value);
      props->Release();
    }

    flutter::EncodableMap m;
    m[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
    m[flutter::EncodableValue("label")] = flutter::EncodableValue(label);
    out.push_back(flutter::EncodableValue(m));

    dev->Release();
  }

  collection->Release();
  enumerator->Release();
  return out;
}

}  // namespace

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------

SystemAudioPlugin::SystemAudioPlugin(flutter::BinaryMessenger* messenger, HWND hwnd)
    : hwnd_(hwnd) {
  DeferredChunkWindowMessage();

  // Method channel
  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "folio/system_audio",
      &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  // Event channel
  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "folio/system_audio_stream",
      &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      // onListen
      [this](const flutter::EncodableValue* /*args*/,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        event_sink_ = std::move(sink);
        return nullptr;
      },
      // onCancel
      [this](const flutter::EncodableValue* /*args*/)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        StopCapture();
        event_sink_ = nullptr;
        return nullptr;
      });

  event_channel_->SetStreamHandler(std::move(handler));
}

SystemAudioPlugin::~SystemAudioPlugin() {
  StopCapture();
}

// static
UINT SystemAudioPlugin::DeferredChunkWindowMessage() {
  static const UINT message_id =
      RegisterWindowMessageW(L"Folio_SystemAudio_DeferredChunk_v1");
  return message_id;
}

void SystemAudioPlugin::ProcessDeferredChunk(LPARAM /*lparam*/) noexcept {
  // Corre en el hilo de plataforma (invocado desde el WndProc) — único lugar
  // donde es seguro tocar event_sink_ y emitir hacia el EventChannel.
  std::vector<std::vector<uint8_t>> pending;
  {
    std::lock_guard<std::mutex> lock(chunk_queue_mutex_);
    pending.swap(chunk_queue_);
  }
  if (!event_sink_) return;
  for (auto& pcm : pending) {
    event_sink_->Success(flutter::EncodableValue(std::move(pcm)));
  }
}

// ---------------------------------------------------------------------------
// Method call handler
// ---------------------------------------------------------------------------

void SystemAudioPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "startCapture") {
    std::string preferred_id;
    if (call.arguments() != nullptr) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args != nullptr) {
        auto it = args->find(flutter::EncodableValue("deviceId"));
        if (it != args->end()) {
          if (const auto* id = std::get_if<std::string>(&it->second)) {
            preferred_id = *id;
          }
        }
      }
    }
    if (StartCapture(preferred_id)) {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("WASAPI_ERROR", "No se pudo iniciar la captura de audio del sistema.");
    }
  } else if (call.method_name() == "stopCapture") {
    StopCapture();
    result->Success(flutter::EncodableValue(true));
  } else if (call.method_name() == "listDevices") {
    result->Success(flutter::EncodableValue(EnumerateRenderDevices()));
  } else {
    result->NotImplemented();
  }
}

// ---------------------------------------------------------------------------
// StartCapture
// ---------------------------------------------------------------------------

bool SystemAudioPlugin::StartCapture(const std::string& preferred_device_id) {
  if (capturing_.load()) return true;
  // Reap a thread from a previous attempt that already finished (e.g. init
  // failed). This does not block: the thread only reaches this state after
  // fully exiting CaptureThreadMain.
  if (capture_thread_.joinable()) capture_thread_.join();

  selected_device_id_ = preferred_device_id;

  auto init_result = std::make_shared<std::promise<bool>>();
  std::future<bool> init_future = init_result->get_future();

  capture_thread_ = std::thread([this, init_result]() {
    CaptureThreadMain(init_result);
  });

  // Bloquea hasta que el hilo termine de inicializar WASAPI (mismo perfil de
  // latencia que antes, cuando la inicialización se hacía en línea aquí
  // mismo). Se hace en el hilo de captura para que todos los objetos COM se
  // creen y usen en el mismo apartment MTA correctamente inicializado.
  try {
    return init_future.get();
  } catch (...) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// CaptureThreadMain — todo el ciclo de vida de WASAPI/COM vive aquí.
// ---------------------------------------------------------------------------

void SystemAudioPlugin::CaptureThreadMain(
    std::shared_ptr<std::promise<bool>> init_result) {
  const HRESULT com_hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool com_owned = SUCCEEDED(com_hr);
  if (FAILED(com_hr) && com_hr != RPC_E_CHANGED_MODE) {
    init_result->set_value(false);
    return;
  }

  WAVEFORMATEX* wfx = nullptr;
  bool ok = false;
  try {
    ok = InitWasapiLoopback(&wfx);
  } catch (...) {
    ok = false;
  }

  if (!ok) {
    ReleaseWasapiResources();
    if (com_owned) CoUninitialize();
    init_result->set_value(false);
    return;
  }

  capturing_.store(true);
  init_result->set_value(true);

  DWORD task_index = 0;
  HANDLE task_handle = AvSetMmThreadCharacteristics(L"Audio", &task_index);

  try {
    RunCaptureLoop(wfx);
  } catch (...) {
    // Degradar a "captura detenida" en vez de tumbar el proceso ante un
    // fallo inesperado de un driver/APO de audio de terceros.
  }

  if (task_handle) AvRevertMmThreadCharacteristics(task_handle);
  CoTaskMemFree(wfx);
  ReleaseWasapiResources();
  capturing_.store(false);
  if (com_owned) CoUninitialize();
}

bool SystemAudioPlugin::InitWasapiLoopback(WAVEFORMATEX** out_format) {
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(&enumerator_));
  if (FAILED(hr)) return false;

  // Render endpoint (default or selected) — loopback records what's playing.
  device_ = FindRenderEndpointById(enumerator_, selected_device_id_);
  if (!device_) {
    hr = enumerator_->GetDefaultAudioEndpoint(eRender, eConsole, &device_);
    if (FAILED(hr)) return false;
  }

  hr = device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(&audio_client_));
  if (FAILED(hr)) return false;

  WAVEFORMATEX* mix_format = nullptr;
  hr = audio_client_->GetMixFormat(&mix_format);
  if (FAILED(hr) || !mix_format) return false;

  // 200 ms buffer, loopback mode
  const REFERENCE_TIME requested_duration = 2000000;  // 200ms in 100ns units
  hr = audio_client_->Initialize(
      AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_LOOPBACK,
      requested_duration, 0, mix_format, nullptr);
  if (FAILED(hr)) { CoTaskMemFree(mix_format); return false; }

  hr = audio_client_->GetService(__uuidof(IAudioCaptureClient),
                                  reinterpret_cast<void**>(&capture_client_));
  if (FAILED(hr)) { CoTaskMemFree(mix_format); return false; }

  hr = audio_client_->Start();
  if (FAILED(hr)) { CoTaskMemFree(mix_format); return false; }

  *out_format = mix_format;
  return true;
}

// ---------------------------------------------------------------------------
// RunCaptureLoop  (runs on capture_thread_, dentro del apartment MTA propio)
// ---------------------------------------------------------------------------

void SystemAudioPlugin::RunCaptureLoop(const WAVEFORMATEX* wfx) {
  while (capturing_.load()) {
    UINT32 packet_length = 0;
    HRESULT hr = capture_client_->GetNextPacketSize(&packet_length);
    if (FAILED(hr)) return;

    while (packet_length > 0) {
      BYTE* data = nullptr;
      UINT32 num_frames = 0;
      DWORD flags = 0;
      hr = capture_client_->GetBuffer(&data, &num_frames, &flags, nullptr, nullptr);
      if (FAILED(hr)) return;

      if (num_frames > 0 && !(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
        auto pcm = ConvertToInt16Mono16k(data, num_frames, wfx);
        if (!pcm.empty()) {
          EnqueueChunkForUiThread(std::move(pcm));
        }
      }

      capture_client_->ReleaseBuffer(num_frames);
      hr = capture_client_->GetNextPacketSize(&packet_length);
      if (FAILED(hr)) return;
    }

    Sleep(10);  // 10ms polling interval
  }
}

void SystemAudioPlugin::EnqueueChunkForUiThread(std::vector<uint8_t> pcm) {
  // NUNCA llamar a event_sink_->Success() desde este hilo: el motor de
  // Flutter en Windows trata el tráfico de canal de plataforma emitido
  // fuera del hilo de plataforma como fatal (fast-fail 0xC0000409). Se
  // encola y se despacha vía mensaje de ventana al hilo de plataforma
  // (ver SystemAudioPlugin::ProcessDeferredChunk).
  {
    std::lock_guard<std::mutex> lock(chunk_queue_mutex_);
    chunk_queue_.push_back(std::move(pcm));
  }
  if (hwnd_ && IsWindow(hwnd_)) {
    PostMessageW(hwnd_, DeferredChunkWindowMessage(), 0, 0);
  }
}

// ---------------------------------------------------------------------------
// StopCapture
// ---------------------------------------------------------------------------

void SystemAudioPlugin::ReleaseWasapiResources() {
  if (audio_client_) { audio_client_->Stop(); }
  if (capture_client_) { capture_client_->Release(); capture_client_ = nullptr; }
  if (audio_client_) { audio_client_->Release(); audio_client_ = nullptr; }
  if (device_) { device_->Release(); device_ = nullptr; }
  if (enumerator_) { enumerator_->Release(); enumerator_ = nullptr; }
}

void SystemAudioPlugin::StopCapture() {
  if (!capturing_.load() && !capture_thread_.joinable()) return;
  capturing_.store(false);

  // CaptureThreadMain libera los objetos WASAPI/COM y hace CoUninitialize()
  // antes de salir, así que aquí solo esperamos a que termine.
  if (capture_thread_.joinable()) capture_thread_.join();

  std::lock_guard<std::mutex> lock(chunk_queue_mutex_);
  chunk_queue_.clear();
}
