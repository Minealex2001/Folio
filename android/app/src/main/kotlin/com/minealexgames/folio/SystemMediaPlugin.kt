package com.minealexgames.folio

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge Now Playing del sistema vía [MediaSessionManager] + Notification Listener.
 *
 * Channels: `folio/system_media`, `folio/system_media_events`
 */
class SystemMediaPlugin(
	private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

	private val mainHandler = Handler(Looper.getMainLooper())
	private var eventSink: EventChannel.EventSink? = null
	private var sessionListener: MediaSessionManager.OnActiveSessionsChangedListener? = null
	private var activeController: MediaController? = null
	private val controllerCallback = object : MediaController.Callback() {
		override fun onMetadataChanged(metadata: MediaMetadata?) {
			emitCurrent()
		}

		override fun onPlaybackStateChanged(state: PlaybackState?) {
			emitCurrent()
		}
	}

	fun register(messenger: BinaryMessenger) {
		MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
		EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"isSupported" -> result.success(true)
			"hasPermission" -> result.success(hasNotificationListenerPermission())
			"openPermissionSettings" -> {
				openPermissionSettings()
				result.success(null)
			}
			"getCurrent" -> result.success(currentSnapshotMap())
			"startListening" -> {
				startListeningInternal()
				result.success(null)
			}
			"stopListening" -> {
				stopListeningInternal()
				result.success(null)
			}
			"play" -> {
				activeOrFirstController()?.transportControls?.play()
				result.success(null)
			}
			"pause" -> {
				activeOrFirstController()?.transportControls?.pause()
				result.success(null)
			}
			"skipNext" -> {
				activeOrFirstController()?.transportControls?.skipToNext()
				result.success(null)
			}
			"skipPrevious" -> {
				activeOrFirstController()?.transportControls?.skipToPrevious()
				result.success(null)
			}
			"seek" -> {
				val positionMs = (call.argument<Number>("positionMs")?.toLong()) ?: 0L
				activeOrFirstController()?.transportControls?.seekTo(positionMs)
				result.success(null)
			}
			else -> result.notImplemented()
		}
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
		eventSink = events
		startListeningInternal()
		emitCurrent()
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
		stopListeningInternal()
	}

	private fun listenerComponent(): ComponentName =
		ComponentName(context, FolioMediaNotificationListener::class.java)

	private fun hasNotificationListenerPermission(): Boolean {
		val flat = Settings.Secure.getString(
			context.contentResolver,
			"enabled_notification_listeners",
		) ?: return false
		val component = listenerComponent()
		val flattened = component.flattenToString()
		val pkg = component.packageName
		val colonSplitter = TextUtils.SimpleStringSplitter(':')
		colonSplitter.setString(flat)
		while (colonSplitter.hasNext()) {
			val enabled = colonSplitter.next()
			if (enabled.equals(flattened, ignoreCase = true) ||
				enabled.startsWith("$pkg/", ignoreCase = true)
			) {
				return true
			}
		}
		return false
	}

	private fun openPermissionSettings() {
		val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		context.startActivity(intent)
	}

	private fun mediaSessionManager(): MediaSessionManager? =
		context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager

	private fun activeSessions(): List<MediaController> {
		if (!hasNotificationListenerPermission()) return emptyList()
		return try {
			mediaSessionManager()?.getActiveSessions(listenerComponent()) ?: emptyList()
		} catch (_: SecurityException) {
			emptyList()
		} catch (_: Exception) {
			emptyList()
		}
	}

	private fun pickPreferredController(sessions: List<MediaController>): MediaController? {
		if (sessions.isEmpty()) return null
		val playing = sessions.firstOrNull { controller ->
			val state = controller.playbackState?.state
			state == PlaybackState.STATE_PLAYING || state == PlaybackState.STATE_BUFFERING
		}
		return playing ?: sessions.first()
	}

	private fun activeOrFirstController(): MediaController? {
		val current = activeController
		if (current != null) return current
		val picked = pickPreferredController(activeSessions())
		bindController(picked)
		return picked
	}

	private fun bindController(controller: MediaController?) {
		activeController?.unregisterCallback(controllerCallback)
		activeController = controller
		controller?.registerCallback(controllerCallback, mainHandler)
	}

	private fun startListeningInternal() {
		if (sessionListener != null) return
		if (!hasNotificationListenerPermission()) {
			bindController(null)
			return
		}
		val manager = mediaSessionManager() ?: return
		val listener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
			val list = controllers ?: emptyList()
			bindController(pickPreferredController(list))
			emitCurrent()
		}
		sessionListener = listener
		try {
			manager.addOnActiveSessionsChangedListener(listener, listenerComponent(), mainHandler)
		} catch (_: SecurityException) {
			sessionListener = null
			return
		}
		bindController(pickPreferredController(activeSessions()))
	}

	private fun stopListeningInternal() {
		val listener = sessionListener
		if (listener != null) {
			try {
				mediaSessionManager()?.removeOnActiveSessionsChangedListener(listener)
			} catch (_: Exception) {
				// ignore
			}
			sessionListener = null
		}
		bindController(null)
	}

	private fun emitCurrent() {
		val sink = eventSink ?: return
		val map = currentSnapshotMap()
		mainHandler.post {
			try {
				sink.success(map)
			} catch (_: Exception) {
				// sink closed
			}
		}
	}

	private fun currentSnapshotMap(): Map<String, Any?> {
		val controller = activeOrFirstController() ?: return emptySnapshotMap()
		val metadata = controller.metadata
		val state = controller.playbackState
		val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE).orEmpty()
		val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
			?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST).orEmpty()
		val appId = controller.packageName.orEmpty()
		val appName = try {
			val pm = context.packageManager
			val appInfo = pm.getApplicationInfo(appId, 0)
			pm.getApplicationLabel(appInfo)?.toString().orEmpty()
		} catch (_: Exception) {
			appId
		}
		val isPlaying = state?.state == PlaybackState.STATE_PLAYING ||
			state?.state == PlaybackState.STATE_BUFFERING
		val progressMs = state?.position ?: 0L
		val durationMs = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
		val actions = state?.actions ?: 0L
		return mapOf(
			"title" to title,
			"artist" to artist,
			"appId" to appId,
			"appName" to appName,
			"albumArt" to ByteArray(0),
			"isPlaying" to isPlaying,
			"progressMs" to progressMs.toInt(),
			"durationMs" to durationMs.toInt(),
			"canPlay" to (actions and PlaybackState.ACTION_PLAY != 0L ||
				actions and PlaybackState.ACTION_PLAY_PAUSE != 0L),
			"canPause" to (actions and PlaybackState.ACTION_PAUSE != 0L ||
				actions and PlaybackState.ACTION_PLAY_PAUSE != 0L),
			"canSkipNext" to (actions and PlaybackState.ACTION_SKIP_TO_NEXT != 0L),
			"canSkipPrevious" to (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS != 0L),
			"canSeek" to (actions and PlaybackState.ACTION_SEEK_TO != 0L),
		)
	}

	private fun emptySnapshotMap(): Map<String, Any?> = mapOf(
		"title" to "",
		"artist" to "",
		"appId" to "",
		"appName" to "",
		"albumArt" to ByteArray(0),
		"isPlaying" to false,
		"progressMs" to 0,
		"durationMs" to 0,
		"canPlay" to false,
		"canPause" to false,
		"canSkipNext" to false,
		"canSkipPrevious" to false,
		"canSeek" to false,
	)

	companion object {
		const val METHOD_CHANNEL = "folio/system_media"
		const val EVENT_CHANNEL = "folio/system_media_events"
	}
}
