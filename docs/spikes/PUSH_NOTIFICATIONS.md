# Spike: notificaciones push (Fase 4, mejoras post-Firebase)

Decisión de proveedor para el groundwork de push notifications — la mayor capacidad nueva de la
iniciativa de infraestructura post-Firebase, y la única con una decisión de vendor explícita
pendiente (mismo patrón que el spike de CRDT en la iniciativa de colaboración).

## Opciones consideradas

1. **`firebase_messaging` (Flutter) + Firebase Admin SDK server-side.** Camino de menor
   resistencia (FCM es efectivamente obligatorio para push en background de Android), y puede
   además puentear APNs para iOS. Pero reintroduce un proyecto Firebase completo
   (`google-services.json`/`GoogleService-Info.plist`, consola de Firebase) — justo la superficie
   de vendor que `MIGRACION_SPRINGBOOT.md` documenta haber dejado atrás.
2. **FCM HTTP v1 directo (JWT de service account, sin SDK) + APNs HTTP/2 directo.** Evita el SDK de
   Firebase Admin y cualquier acoplamiento a Firestore/Auth/Analytics. Android sigue necesitando un
   proyecto de Google Cloud con la API de FCM habilitada — eso es una realidad de la plataforma
   (no hay transporte de push en background para Android que evite por completo la infraestructura
   de Google), no una elección de diseño de Folio.

## Decisión: Opción 2 — sin Firebase

Implementado así en `FolioBackend/src/main/java/com/folio/backend/notifications/`:

- `FcmHttpV1PushSender`: intercambia el JSON de un service account de Google Cloud por un access
  token OAuth2 (JWT RS256 firmado con la clave privada del service account, sin librería de
  Firebase) y llama a `POST https://fcm.googleapis.com/v1/projects/{project}/messages:send`
  directamente.
- `ApnsPushSender`: JWT ES256 construido a mano con JDK puro (sin librería JWT, por la conversión
  DER→JWS de la firma que no quise delegar a una API que no podía verificar sin compilador) y
  llamada HTTP/2 directa a `api.push.apple.com` / `api.sandbox.push.apple.com`.

**Nota inevitable de nombres**: el scope OAuth (`.../auth/firebase.messaging`) y el dominio de la
API (`fcm.googleapis.com`) siguen diciendo "firebase" porque así se llama hoy la API de push de
Android en Google Cloud — no implica ningún acoplamiento a Firestore/Auth/Analytics/consola de
Firebase, y no requiere el SDK de Firebase Admin en ningún punto.

## Estado: groundwork, no verificado contra endpoints reales

Ninguno de los dos sender se probó contra las APIs reales de Google/Apple en este entorno (sin
credenciales disponibles). Antes de confiar en esto para push de producción:

1. Provisionar un service account de Google Cloud con el rol de FCM y una clave de auth APNs
   (`.p8`) de Apple Developer.
2. Probar `FcmHttpV1PushSender`/`ApnsPushSender` en staging con un token de dispositivo real.
3. Prestar especial atención a la conversión DER→JWS de la firma ECDSA en `ApnsPushSender`
   (`derToJwsSignature`) — es la parte de mayor riesgo de todo el groundwork; un error ahí
   invalidaría todos los pushes a iOS de forma silenciosa hasta la primera prueba real.

## Diseño independiente del proveedor

- `DeviceTokenEntity`/`DeviceTokenController` (`POST /api/v1/notifications/device-tokens`,
  `DELETE .../{token}`) — registro/baja de tokens, varios por usuario (varios dispositivos).
- `PushNotificationService` — interfaz única (`send(uid, title, body, data)`); el proveedor queda
  detrás de `PushNotificationDispatcher`, intercambiable sin tocar los puntos de disparo.
- Disparador cableado end-to-end como demostración: invitación a sala de colaboración
  (`CollabService.inviteMember`). El resto de disparadores previstos (comandos de integración
  pendientes, backup completado, invitaciones familiares, vault shares) siguen el mismo patrón —
  llamar a `pushNotificationService.send(...)` tras la operación exitosa — y quedan como
  siguiente paso natural, no implementados en esta pasada para mantener el alcance acotado.
- Preferencia/opt-out de notificaciones: no implementado todavía. Antes de activar esto en
  producción, reflejar la granularidad que ya existe en el patrón
  `notifyOnStatusChange`/`notifyOnNewTask`/`notifyOnComment` de las integraciones — no asumir
  "notificar todo por defecto".

## Cliente Flutter: pendiente

Este groundwork es solo backend. Falta: registrar el token del dispositivo tras el login (llamando
a `POST /api/v1/notifications/device-tokens`), obtener el token nativo de FCM/APNs (requiere un
plugin Flutter — evaluar alternativas al paquete `firebase_messaging` dado que la decisión fue
evitar Firebase; comprobar en pub.dev si existe un plugin FCM+APNs unificado sin Firebase de
Google, o si hace falta un platform channel a mano), y manejar la recepción/tap de la notificación
en primer y segundo plano.
