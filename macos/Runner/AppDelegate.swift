import Cocoa
import AVFoundation
import CoreMedia
import FlutterMacOS
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

#if canImport(ScreenCaptureKit)
@available(macOS 12.3, *)
final class SystemAudioPlugin: NSObject, FlutterStreamHandler, SCStreamDelegate, SCStreamOutput {
  private var eventSink: FlutterEventSink?
  private var stream: SCStream?
  private let outputQueue = DispatchQueue(label: "folio.system_audio", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SystemAudioPlugin()

    let methodChannel = FlutterMethodChannel(
      name: "folio/system_audio",
      binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: "folio/system_audio_stream",
      binaryMessenger: registrar.messenger)
    eventChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCapture":
      startCapture(result: result)
    case "stopCapture":
      stopCapture(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func startCapture(result: @escaping FlutterResult) {
    if stream != nil {
      result(true)
      return
    }

    SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
      guard let self else {
        result(false)
        return
      }
      if let error {
        result(FlutterError(code: "SC_CONTENT", message: error.localizedDescription, details: nil))
        return
      }
      guard let display = content?.displays.first else {
        result(FlutterError(code: "SC_DISPLAY", message: "No hay pantallas disponibles para capturar audio del sistema.", details: nil))
        return
      }

      let config = SCStreamConfiguration()
      config.capturesAudio = true
      config.sampleRate = 48_000
      config.channelCount = 2
      config.queueDepth = 6
      config.excludesCurrentProcessAudio = false

      let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
      let stream = SCStream(filter: filter, configuration: config, delegate: self)

      do {
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.outputQueue)
        stream.startCapture { error in
          if let error {
            result(FlutterError(code: "SC_START", message: error.localizedDescription, details: nil))
            return
          }
          self.stream = stream
          result(true)
        }
      } catch {
        result(FlutterError(code: "SC_OUTPUT", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func stopCapture(result: @escaping FlutterResult) {
    guard let stream else {
      result(true)
      return
    }

    stream.stopCapture { [weak self] _ in
      self?.stream = nil
      result(true)
    }
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    eventSink?(FlutterError(code: "SC_STREAM", message: error.localizedDescription, details: nil))
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
    guard outputType == .audio,
          CMSampleBufferIsValid(sampleBuffer),
          let format = CMSampleBufferGetFormatDescription(sampleBuffer),
          let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(format)
    else {
      return
    }

    let asbd = asbdPtr.pointee
    var blockBuffer: CMBlockBuffer?
    var audioBufferList = AudioBufferList(
      mNumberBuffers: 1,
      mBuffers: AudioBuffer(mNumberChannels: 0, mDataByteSize: 0, mData: nil)
    )

    let status = withUnsafeMutablePointer(to: &audioBufferList) { listPointer in
      listPointer.withMemoryRebound(to: AudioBufferList.self, capacity: 1) { rebound in
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
          sampleBuffer,
          bufferListSizeNeededOut: nil,
          bufferListOut: rebound,
          bufferListSize: MemoryLayout<AudioBufferList>.size,
          blockBufferAllocator: kCFAllocatorDefault,
          blockBufferMemoryAllocator: kCFAllocatorDefault,
          flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
          blockBufferOut: &blockBuffer
        )
      }
    }

    guard status == noErr,
          audioBufferList.mBuffers.mDataByteSize > 0,
          let data = audioBufferList.mBuffers.mData
    else {
      return
    }

    let bytes = Int(audioBufferList.mBuffers.mDataByteSize)
    let channels = max(Int(asbd.mChannelsPerFrame), 1)
    let sourceRate = max(Double(asbd.mSampleRate), 1)
    let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
    let isSigned16 = asbd.mBitsPerChannel == 16

    let mono16k = convertToInt16Mono16k(
      source: data,
      byteCount: bytes,
      channels: channels,
      sourceRate: sourceRate,
      isFloat: isFloat,
      isSigned16: isSigned16
    )
    if !mono16k.isEmpty {
      eventSink?(FlutterStandardTypedData(bytes: mono16k))
    }
  }

  private func convertToInt16Mono16k(
    source: UnsafeMutableRawPointer,
    byteCount: Int,
    channels: Int,
    sourceRate: Double,
    isFloat: Bool,
    isSigned16: Bool
  ) -> Data {
    let frameCount: Int
    var mono = [Float]()

    if isFloat {
      let sampleCount = byteCount / MemoryLayout<Float>.size
      frameCount = sampleCount / channels
      let samples = source.bindMemory(to: Float.self, capacity: sampleCount)
      mono.reserveCapacity(frameCount)
      for frame in 0..<frameCount {
        var sum: Float = 0
        for channel in 0..<channels {
          sum += samples[frame * channels + channel]
        }
        mono.append(sum / Float(channels))
      }
    } else if isSigned16 {
      let sampleCount = byteCount / MemoryLayout<Int16>.size
      frameCount = sampleCount / channels
      let samples = source.bindMemory(to: Int16.self, capacity: sampleCount)
      mono.reserveCapacity(frameCount)
      for frame in 0..<frameCount {
        var sum: Float = 0
        for channel in 0..<channels {
          sum += Float(samples[frame * channels + channel]) / 32768.0
        }
        mono.append(sum / Float(channels))
      }
    } else {
      return Data()
    }

    let targetRate = 16_000.0
    let ratio = sourceRate / targetRate
    let outFrames = max(Int(Double(frameCount) / ratio), 0)
    var output = Data(count: outFrames * MemoryLayout<Int16>.size)

    output.withUnsafeMutableBytes { rawBuffer in
      guard let out = rawBuffer.bindMemory(to: Int16.self).baseAddress else {
        return
      }
      for i in 0..<outFrames {
        let position = Double(i) * ratio
        let index = min(Int(position), max(frameCount - 1, 0))
        let nextIndex = min(index + 1, max(frameCount - 1, 0))
        let fraction = Float(position - Double(index))
        let interpolated = mono[index] + ((mono[nextIndex] - mono[index]) * fraction)
        let clamped = max(-1.0, min(1.0, interpolated))
        out[i] = Int16(clamped * 32767.0)
      }
    }

    return output
  }
}
#endif

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
#if canImport(ScreenCaptureKit)
    if #available(macOS 12.3, *),
       let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      SystemAudioPlugin.register(with: controller.registrar(forPlugin: "SystemAudioPlugin"))
    }
#endif
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
