# Backend Folio Cloud (autoridad)

El cliente Flutter **no es confiable**: cualquiera puede modificar el código. Toda lógica de negocio crítica debe ejecutarse en:

- **Cloud Functions** (callables con `request.auth`, webhooks firmados por Stripe).
- **Firestore**: documento `users/{uid}` con `allow write: if false` para el SDK cliente; solo el **Admin SDK** en Functions escribe `folioCloud`, `ink`, `stripeCustomerId`.
- **Idempotencia**: eventos Stripe en `stripeWebhookEvents/{eventId}`; sesiones Checkout de pago único en `stripeProcessedCheckouts/{sessionId}` para no sumar gotas dos veces (`completed` + `async_payment_succeeded`).
- **Índice de suscriptores mensuales**: `folioCloudSubscribers/{uid}` (solo Functions) para la recarga de gotas el día 1 sin escanear toda la colección `users`.

## Cliente Flutter (Windows / Linux)

El paquete `cloud_functions` **no** expone en Windows (ni en Linux en muchos builds) el plugin nativo de Firebase; el canal Pigeon falla. Las callables de Folio (`createCheckoutSession`, `createBillingPortalSession`, `folioCloudAiComplete`, `folioListVaultBackups`) usan en esas plataformas el **protocolo HTTP** (`Authorization: Bearer` + ID token) con la misma URL `https://REGION-PROJECT_ID.cloudfunctions.net/NAME` que documenta Firebase; ver [callable-reference](https://firebase.google.com/docs/functions/callable-reference) y implementación en [`lib/services/folio_cloud/folio_cloud_callable.dart`](../lib/services/folio_cloud/folio_cloud_callable.dart).

**IA en nube (`folioCloudAiComplete`):** está desplegada como Cloud Function **1st gen** (`firebase-functions/v1`), es decir en la infraestructura clásica de `cloudfunctions.net`, **no** como función v2 sobre Cloud Run. Así se evita el perímetro IAM y muchos **HTTP 429** que en escritorio se confunden con límites de tinta. El resto de callables del repo siguen en **v2** (Cloud Run); para ellas aplica el aviso IAM de abajo. Si en el proyecto ya existía `folioCloudAiComplete` como v2, conviene **borrarla** (consola GCP o `firebase functions:delete folioCloudAiComplete --region us-central1` según tu flujo) y luego `firebase deploy --only functions` para que solo quede la 1st gen con el mismo nombre.

Como refuerzo para escritorio, también existe `folioCloudAiCompleteHttp` (HTTP **v1**). El cliente Windows/Linux lo usa solo si la callable devuelve **401 HTML** (bloqueo de infraestructura antes de entrar al protocolo callable). Este endpoint mantiene la misma validación de negocio (auth, tinta, cargo/reembolso) y responde en formato compatible con callable (`{result}` o `{error:{status,message}}`). La IA en nube está permitida si hay **suscripción activa con `cloudAi`** o, sin ello, si hay **tinta comprada** (`ink.purchasedBalance`); la tinta mensual del plan no se consume en ese segundo modo y al perder la suscripción `syncSubscriptionToUser` pone **`ink.monthlyBalance` en 0** conservando la comprada.

### Aviso: 401 con página HTML «Error 401 (Unauthorized)»

Eso **no** es (por lo general) un token de Firebase mal renovado: es el **perímetro de Google Cloud** rechazando la petición antes de entrar en el protocolo callable. Las funciones **v2** viven en **Cloud Run**; hace falta que el servicio permita **invocación pública** (`allUsers` con rol **Invocador de Cloud Run** / `roles/run.invoker`). La identidad del usuario sigue validándose **dentro** de la función con el `Authorization: Bearer` (ID token).

En la app, el mensaje visible al usuario se orienta a **suscripción Folio Cloud activa** y revisión en Ajustes; el detalle IAM queda documentado aquí para quien despliega el backend.

**Qué hacer:** Google Cloud Console → **Cloud Run** → el servicio que corresponde a la función (misma región que el despliegue, p. ej. `us-central1`) → **Seguridad** / **Permisos** → permitir invocaciones sin autenticación, o desde terminal (sustituye `SERVICE_NAME` por el nombre del servicio, p. ej. el que lista `gcloud run services list --region=us-central1`):

```bash
gcloud run services add-iam-policy-binding SERVICE_NAME \
  --project=folio-minealexgames \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/run.invoker
```

Si una política de organización impide `allUsers`, hay que alinear excepciones con el administrador del proyecto. Tras un despliegue manual o cambios de IAM, a veces hace falta **volver a desplegar** las functions o repetir `firebase deploy --only functions`.

## Storage y publicación web

- **`users/{uid}/backups/**`**: escritura solo si `folioCloud.active` y `folioCloud.features.backup` (reglas en [`storage.rules`](../storage.rules)). En **Windows/Linux** el cliente no puede listar con `listAll()` (SDK C++ devuelve vacío); la app usa la callable **`folioListVaultBackups`**, que lista con Admin SDK (misma condición de plan en servidor).
- **`published/{uid}/**`**: lectura pública; escritura solo con `features.publishWeb`. El índice Firestore `publishedPages` exige lo mismo (solo cliente con plan; el HTML sigue en Storage).

## Flujos en la app (cliente)

- **Suscripción mensual Folio Cloud** (Stripe → webhook → `users/{uid}.folioCloud`): activa las tres capacidades que el backend expone como `features`: `backup`, `cloudAi`, `publishWeb` (ver `folioCloudFeaturesFromPriceId` en Functions).
- **Copia en la nube**: Ajustes → subir/listar/descargar ZIP cifrado; el cliente puede pasar un snapshot de entitlements para fallar antes de Storage (las reglas siguen siendo la autoridad).
- **Copia programada local**: si el usuario activa “Subir también a Folio Cloud” y tiene sesión Firebase + `canUseCloudBackup`, tras un backup programado exitoso se sube el mismo ZIP con `uploadEncryptedBackupFile`.
- **Publicación web**: desde el workspace, “Publicar en la web” exporta la página actual a HTML (Markdown → HTML simple) y llama a `publishHtmlPage`; en Ajustes hay listado de `publishedPages`, enlace y borrado (Storage + Firestore).
- **IA en nube**: `folioCloudAiComplete` acepta **suscripción con `cloudAi`** o **solo tinta comprada** (sin suscripción); el cliente elige Folio Cloud cuando `canUseCloudAi` (misma regla en UI). Si OpenAI devuelve **401/403/429** (clave, cuota o facturación), el error es de la **API de OpenAI**, no de las gotas Folio en Firestore. Mensajes técnicos del upstream pueden aparecer en el detalle del error. En el cliente, valores de `ink` absurdamente altos en Firestore se **acotan solo para mostrar** en la UI; conviene corregir el documento `users/{uid}` si fue un error de datos.

## Gotas y Quill en nube

- **Entrada** (callable `folioCloudAiComplete`): cuerpo con `prompt` (obligatorio) y `operationKind` (opcional). Si `operationKind` no está en la tabla del servidor, se usa `default`.
- **Entrada** (callable `folioCloudAiComplete`): soporta **dos formatos** (compatibilidad hacia atrás):
  - **Legacy**: `prompt` (string) + `operationKind` (opcional).
  - **Estructurado**: `prompt` (string, opcional si hay `messages`), `systemPrompt` (string opcional), `messages` (array de `{role:"system|user|assistant", content:string}`), `responseSchema` (JSON Schema opcional), `temperature` (number opcional), `maxTokens` (int opcional), y `operationKind` (opcional).
  
  El backend usa `messages` + `systemPrompt` cuando se envían; si no, cae al modo legacy con un único mensaje de usuario construido desde `prompt`.
- **Coste base** por `operationKind` (archivo [`functions/src/index.ts`](../functions/src/index.ts), constante `INK_COST_BY_OPERATION`):

| `operationKind`   | Gotas base |
|-------------------|------------|
| `rewrite_block`   | 1          |
| `summarize_selection` | 1    |
| `extract_tasks`   | 2          |
| `summarize_page`  | 3          |
| `generate_insert` | 5          |
| `generate_page`   | 8          |
| `chat_turn`       | 3          |
| `agent_main`      | 10         |
| `agent_followup`  | 4          |
| `edit_page_panel` | 4          |
| `default`         | 3          |

- **Límites y suplementos** (mismo archivo): `INK_MAX_PER_REQUEST` (tope por llamada). Si el **input total** (suma aproximada de `prompt` + `systemPrompt` + `messages[].content`) supera `INK_PROMPT_LENGTH_SURCHARGE_THRESHOLD` caracteres, se suman gotas extra (`INK_EXTRA_FOR_LONG_PROMPT`). Tras una respuesta exitosa de OpenAI, puede aplicarse un **suplemento por tokens** según `usage.total_tokens` (`INK_TOKENS_PER_SURCHARGE_UNIT`, tope `INK_MAX_TOKEN_SURCHARGE`).
- `folioCloudAiComplete` (callable **1st gen**) exige `folioCloud.active` y `features.cloudAi`, descuenta el coste base en una transacción y llama a **OpenAI** Chat Completions (`OPENAI_API_KEY`). Si la IA falla después del débito, se reembolsa el **mismo** importe base (`refundInkDropCharge`). Sin tinta suficiente: `HttpsError` con código `resource-exhausted`.
- **Respuesta** al cliente (JSON): `text` (string), `ink: { monthlyBalance, purchasedBalance }` (enteros), `inkCharged` (base + suplemento por tokens cobrado), `inkBaseCharged`, `inkTokenSurcharge`. El cliente Flutter aplica `ink` al `FolioCloudEntitlementsController` para no esperar solo al stream de Firestore.

### Referencia: API de OpenAI

- Documentación: [OpenAI API — Chat Completions](https://platform.openai.com/docs/api-reference/chat/create).
- El backend usa `POST {OPENAI_BASE_URL}/chat/completions` con `Authorization: Bearer` y cuerpo `model`, `messages`, `max_tokens`, `temperature`. `OPENAI_BASE_URL` por defecto es `https://api.openai.com/v1` (compatible con proxies que expongan la misma forma de API).
- Para **cobrar tinta en función del trabajo real**, se lee **`usage.total_tokens`** en la respuesta para el suplemento por tokens además del coste base por `operationKind`.
- El modelo por defecto en código es `gpt-4o-mini`; `OPENAI_MODEL` en Functions lo sobrescribe. Opcionales: `OPENAI_MAX_OUTPUT_TOKENS`, `OPENAI_TEMPERATURE`.
