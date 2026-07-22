package com.minealexgames.folio

import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.GenerateContentResponse
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Bridge to Gemini Nano via ML Kit GenAI Prompt API (AICore).
 *
 * Channel: [METHOD_CHANNEL]
 * Download events: [EVENT_CHANNEL]
 */
class OnDeviceAiPlugin : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

	private val mainHandler = Handler(Looper.getMainLooper())
	private val mainExecutor = Executor { command -> mainHandler.post(command) }
	private var eventSink: EventChannel.EventSink? = null
	private val downloading = AtomicBoolean(false)

	fun register(messenger: BinaryMessenger) {
		MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
		EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"getDeviceBrand" -> result.success(detectBrand())
			"checkStatus" -> checkStatus(result)
			"download" -> download(result)
			"ping" -> ping(result)
			"generateContent" -> {
				val prompt = call.argument<String>("prompt")?.trim().orEmpty()
				if (prompt.isEmpty()) {
					result.error("INVALID_PROMPT", "prompt is required", null)
					return
				}
				generateContent(prompt, result)
			}
			else -> result.notImplemented()
		}
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
		eventSink = events
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
	}

	private fun detectBrand(): String {
		val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
		val brand = Build.BRAND.orEmpty().lowercase()
		val model = Build.MODEL.orEmpty().lowercase()
		return when {
			manufacturer.contains("samsung") || brand.contains("samsung") -> "samsung"
			manufacturer.contains("google") ||
				brand.contains("google") ||
				model.contains("pixel") -> "google"
			else -> "other"
		}
	}

	private fun modelFutures(): GenerativeModelFutures =
		GenerativeModelFutures.from(Generation.getClient())

	private fun statusToString(status: Int): String =
		when (status) {
			FeatureStatus.AVAILABLE -> "available"
			FeatureStatus.DOWNLOADABLE -> "downloadable"
			FeatureStatus.DOWNLOADING -> "downloading"
			else -> "unavailable"
		}

	private fun checkStatus(result: MethodChannel.Result) {
		Futures.addCallback(
			modelFutures().checkStatus(),
			object : FutureCallback<Int> {
				override fun onSuccess(status: Int?) {
					result.success(statusToString(status ?: FeatureStatus.UNAVAILABLE))
				}

				override fun onFailure(t: Throwable) {
					result.error(
						"CHECK_STATUS_FAILED",
						t.message ?: "checkStatus failed",
						null,
					)
				}
			},
			mainExecutor,
		)
	}

	private fun download(result: MethodChannel.Result) {
		if (!downloading.compareAndSet(false, true)) {
			result.error("DOWNLOAD_IN_PROGRESS", "Model download already in progress", null)
			return
		}
		val completed = AtomicBoolean(false)
		fun finishOk() {
			if (!completed.compareAndSet(false, true)) return
			downloading.set(false)
			emitDownloadEvent(mapOf("phase" to "completed"))
			result.success("available")
		}
		fun finishErr(code: String, message: String?) {
			if (!completed.compareAndSet(false, true)) return
			downloading.set(false)
			emitDownloadEvent(
				mapOf(
					"phase" to "failed",
					"message" to (message ?: "download failed"),
				),
			)
			result.error(code, message ?: "download failed", null)
		}
		val future = modelFutures().download(
			object : DownloadCallback {
				override fun onDownloadStarted(bytesToDownload: Long) {
					emitDownloadEvent(
						mapOf(
							"phase" to "started",
							"bytesDownloaded" to 0L,
							"bytesToDownload" to bytesToDownload,
						),
					)
				}

				override fun onDownloadProgress(totalBytesDownloaded: Long) {
					emitDownloadEvent(
						mapOf(
							"phase" to "progress",
							"bytesDownloaded" to totalBytesDownloaded,
						),
					)
				}

				override fun onDownloadCompleted() {
					mainHandler.post { finishOk() }
				}

				override fun onDownloadFailed(e: GenAiException) {
					mainHandler.post { finishErr("DOWNLOAD_FAILED", e.message) }
				}
			},
		)
		Futures.addCallback(
			future,
			object : FutureCallback<Void> {
				override fun onSuccess(value: Void?) {
					finishOk()
				}

				override fun onFailure(t: Throwable) {
					finishErr("DOWNLOAD_FAILED", t.message)
				}
			},
			mainExecutor,
		)
	}

	private fun ping(result: MethodChannel.Result) {
		Futures.addCallback(
			modelFutures().checkStatus(),
			object : FutureCallback<Int> {
				override fun onSuccess(status: Int?) {
					val mapped = statusToString(status ?: FeatureStatus.UNAVAILABLE)
					if (mapped == "available") {
						result.success(mapped)
					} else {
						result.error(
							"NOT_READY",
							"Gemini Nano status: $mapped",
							mapOf("status" to mapped),
						)
					}
				}

				override fun onFailure(t: Throwable) {
					result.error("PING_FAILED", t.message ?: "ping failed", null)
				}
			},
			mainExecutor,
		)
	}

	private fun generateContent(prompt: String, result: MethodChannel.Result) {
		val truncated =
			if (prompt.length > MAX_PROMPT_CHARS) {
				prompt.take(MAX_PROMPT_CHARS)
			} else {
				prompt
			}
		Futures.addCallback(
			modelFutures().generateContent(truncated),
			object : FutureCallback<GenerateContentResponse> {
				override fun onSuccess(response: GenerateContentResponse?) {
					val text =
						response
							?.candidates
							?.firstOrNull()
							?.text
							?.trim()
							.orEmpty()
					if (text.isEmpty()) {
						result.error("EMPTY_RESPONSE", "Gemini Nano returned empty text", null)
					} else {
						result.success(text)
					}
				}

				override fun onFailure(t: Throwable) {
					result.error(
						"GENERATE_FAILED",
						t.message ?: "generateContent failed",
						null,
					)
				}
			},
			mainExecutor,
		)
	}

	private fun emitDownloadEvent(payload: Map<String, Any?>) {
		mainHandler.post {
			eventSink?.success(payload)
		}
	}

	companion object {
		const val METHOD_CHANNEL = "com.minealexgames.folio/on_device_ai"
		const val EVENT_CHANNEL = "com.minealexgames.folio/on_device_ai_download"
		private const val MAX_PROMPT_CHARS = 12000
	}
}
