package dev.folio.app

import android.content.Context
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
			"dev.folio.app/network"
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
