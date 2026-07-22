#ifndef RUNNER_SYSTEM_AUDIO_PLUGIN_H_
#define RUNNER_SYSTEM_AUDIO_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/standard_method_codec.h>

#include <Audioclient.h>
#include <mmdeviceapi.h>
#include <windows.h>

#include <atomic>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

/// Plugin de captura de audio del sistema (loopback WASAPI).
/// Registra los canales:
///   MethodChannel  "folio/system_audio"        — startCapture / stopCapture
///   EventChannel   "folio/system_audio_stream"  — PCM Int16LE 16kHz mono
///
/// Todo el trabajo de WASAPI/COM (creación de objetos y bucle de captura)
/// ocurre íntegramente dentro de `capture_thread_`, que se inicializa como
/// MTA con `CoInitializeEx`. Los chunks de audio capturados NUNCA se envían
/// al EventSink directamente desde ese hilo: se encolan y se despachan al
/// hilo de plataforma vía un mensaje de ventana custom, porque el motor de
/// Flutter en Windows trata el tráfico de canal de plataforma emitido desde
/// un hilo que no es el de plataforma como fatal (fast-fail 0xC0000409).
class SystemAudioPlugin {
 public:
  explicit SystemAudioPlugin(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~SystemAudioPlugin();

  /// Mensaje de ventana custom usado para avisar al hilo de plataforma de que
  /// hay chunks de audio pendientes de despachar al EventSink.
  static UINT DeferredChunkWindowMessage();

  /// Debe llamarse desde el WndProc del hilo de plataforma al recibir
  /// `DeferredChunkWindowMessage()`. Vacía la cola de chunks pendientes y los
  /// entrega al EventSink de forma segura.
  void ProcessDeferredChunk(LPARAM lparam) noexcept;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool StartCapture(const std::string& preferred_device_id);
  void StopCapture();

  // Todo corre en capture_thread_: inicializa COM (MTA), crea los objetos
  // WASAPI, ejecuta el bucle de captura y libera todo antes de salir.
  void CaptureThreadMain(std::shared_ptr<std::promise<bool>> init_result);
  bool InitWasapiLoopback(WAVEFORMATEX** out_format);
  void RunCaptureLoop(const WAVEFORMATEX* wfx);
  void ReleaseWasapiResources();
  void EnqueueChunkForUiThread(std::vector<uint8_t> pcm);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  HWND hwnd_ = nullptr;

  std::thread capture_thread_;
  std::atomic<bool> capturing_{false};

  std::mutex chunk_queue_mutex_;
  std::vector<std::vector<uint8_t>> chunk_queue_;

  // COM objects — creados y usados exclusivamente dentro de capture_thread_.
  IMMDeviceEnumerator* enumerator_ = nullptr;
  IMMDevice* device_ = nullptr;
  IAudioClient* audio_client_ = nullptr;
  IAudioCaptureClient* capture_client_ = nullptr;

  std::string selected_device_id_;
};

#endif  // RUNNER_SYSTEM_AUDIO_PLUGIN_H_
