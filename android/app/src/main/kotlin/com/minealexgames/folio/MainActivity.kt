package com.minealexgames.folio

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private var multicastLock: WifiManager.MulticastLock? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.minealexgames.folio/network"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"acquireMulticastLock" -> {
					acquireMulticastLock()
					result.success(null)
				}

				"releaseMulticastLock" -> {
					releaseMulticastLock()
					result.success(null)
				}

				else -> result.notImplemented()
			}
		}

		// Fallback OAuth / enlaces externos si url_launcher Pigeon no está conectado.
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.minealexgames.folio/browser"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"openUrl" -> openUrl(call.argument<String>("url"), result)
				else -> result.notImplemented()
			}
		}

		OnDeviceAiPlugin().register(flutterEngine.dartExecutor.binaryMessenger)
		SystemMediaPlugin(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
	}

	private fun openUrl(url: String?, result: MethodChannel.Result) {
		if (url.isNullOrBlank()) {
			result.error("bad_args", "url required", null)
			return
		}
		val uri = try {
			Uri.parse(url)
		} catch (e: Exception) {
			result.error("bad_args", "invalid url: ${e.message}", null)
			return
		}
		if (uri.scheme.isNullOrBlank()) {
			result.error("bad_args", "url must include a scheme", null)
			return
		}
		try {
			startActivity(Intent(Intent.ACTION_VIEW, uri))
			result.success(true)
		} catch (_: ActivityNotFoundException) {
			result.success(false)
		} catch (e: Exception) {
			result.error("open_failed", e.message, null)
		}
	}

	private fun acquireMulticastLock() {
		val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
			?: return
		val lock = multicastLock ?: wifiManager.createMulticastLock("folio_device_sync").apply {
			setReferenceCounted(false)
		}.also {
			multicastLock = it
		}
		if (!lock.isHeld) {
			lock.acquire()
		}
	}

	private fun releaseMulticastLock() {
		val lock = multicastLock ?: return
		if (lock.isHeld) {
			lock.release()
		}
	}

	override fun onDestroy() {
		releaseMulticastLock()
		super.onDestroy()
	}
}
