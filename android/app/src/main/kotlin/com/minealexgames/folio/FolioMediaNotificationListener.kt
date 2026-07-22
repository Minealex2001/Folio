package com.minealexgames.folio

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Listener mínimo requerido para [android.media.session.MediaSessionManager.getActiveSessions].
 * No procesa notificaciones; solo habilita el acceso a sesiones multimedia activas.
 */
class FolioMediaNotificationListener : NotificationListenerService() {
	override fun onNotificationPosted(sbn: StatusBarNotification?) {
		// no-op
	}

	override fun onNotificationRemoved(sbn: StatusBarNotification?) {
		// no-op
	}

	override fun onListenerConnected() {
		super.onListenerConnected()
	}
}
