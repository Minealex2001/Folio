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
#include <memory>
#include <string>
#include <thread>

/// Plugin de captura de audio del sistema (loopback WASAPI).
/// Registra los canales:
///   MethodChannel  "folio/system_audio"        — startCapture / stopCapture
///   EventChannel   "folio/system_audio_stream"  — PCM Int16LE 16kHz mono
class SystemAudioPlugin {
 public:
  explicit SystemAudioPlugin(flutter::BinaryMessenger* messenger);
  ~SystemAudioPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool StartCapture(const std::string& preferred_device_id);
  void StopCapture();
  void CaptureLoop();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::thread capture_thread_;
  std::atomic<bool> capturing_{false};

  // COM objects
  IMMDeviceEnumerator* enumerator_ = nullptr;
  IMMDevice* device_ = nullptr;
  IAudioClient* audio_client_ = nullptr;
  IAudioCaptureClient* capture_client_ = nullptr;

  std::string selected_device_id_;
};

#endif  // RUNNER_SYSTEM_AUDIO_PLUGIN_H_
