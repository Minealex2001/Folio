# Folio Cloud — secretos y código abierto

Folio es **open source**. Ninguna credencial con poder real debe estar en el repositorio.

## Qué nunca debe estar en Git

| Secreto | Uso |
|--------|-----|
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | Pagos y verificación de webhooks (solo **Cloud Functions** / Secret Manager) |
| `OPENAI_API_KEY` (y opcional `OPENAI_MODEL`, `OPENAI_BASE_URL`) | IA en nube (`folioCloudAiComplete`); clave desde [OpenAI Platform](https://platform.openai.com/api-keys) |
| Claves de proveedores de IA (Vertex, OpenAI, etc.) | Solo en el servidor que hace inferencia |
| Tokens de API de terceros | Mismo criterio |

## Firebase en el cliente

- `lib/firebase_options.dart` identifica el proyecto. Restringe en [Firebase Console](https://console.firebase.google.com) por app (SHA-256 Android, bundle iOS, etc.).
- Para forks: genera el tuyo con `flutterfire configure` o usa un proyecto de desarrollo aparte.
- Opcional: no commitear `firebase_options.dart` de producción y generarlo en CI con secretos (añade el archivo a `.gitignore` solo si adoptáis ese flujo).

## Cloud Functions

- Variables sensibles en **Google Cloud Secret Manager** o `firebase functions:config:set` / `.env` **local** ignorado por Git.
- Copia `functions/.env.example` → `functions/.env` (no subir `.env`). Al arrancar, las Functions cargan ese archivo con **dotenv** (`loadEnv` en `functions/src/index.ts`).
- **`OPENAI_API_KEY`**: el archivo `functions/.env` **no** se sube al desplegar (`firebase.json` lo ignora). En producción define la clave como **variable de entorno** de la función (Firebase Console → *Functions* → tu función → *Configuration* → *Environment variables*, o el flujo que uses en CI). Valor: clave de [OpenAI Platform](https://platform.openai.com/api-keys). Si más adelante usas **Secret Manager** (`firebase functions:secrets:set` + `secrets: [...]` en código), **elimina antes** la variable de entorno plana `OPENAI_API_KEY` en Cloud Run; si coexisten con el mismo nombre, el despliegue falla con *Secret environment variable overlaps non secret environment variable*. Quien desplegaba con `GEMINI_API_KEY` debe sustituirla por `OPENAI_API_KEY` y borrar la variable antigua en Cloud Run.
- Guía paso a paso (webhook, Stripe CLI, emulador): [FOLIO_CLOUD_STRIPE_SETUP.md](FOLIO_CLOUD_STRIPE_SETUP.md).

### Variables de precios Stripe (IDs públicos de precio)

| Variable | Descripción |
|----------|-------------|
| `STRIPE_PRICE_FOLIO_CLOUD_MONTHLY` | Precio suscripción Folio Cloud (4,99 €/mes) |
| `STRIPE_PRICE_INK_SMALL` | Tintero pequeño (300 gotas) |
| `STRIPE_PRICE_INK_MEDIUM` | Tintero mediano (1.000 gotas) |
| `STRIPE_PRICE_INK_LARGE` | Tintero grande (2.500 gotas) |
| `STRIPE_CHECKOUT_SUCCESS_URL` / `STRIPE_CHECKOUT_CANCEL_URL` | URLs de retorno tras Checkout (opcional; si faltan, se usa `BILLING_PORTAL_RETURN_URL`) |

Catálogo orientativo: [FOLIO_CLOUD_STRIPE_PRODUCTS.md](FOLIO_CLOUD_STRIPE_PRODUCTS.md). Arquitectura servidor: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).

## Cliente Flutter

- No incluyas claves de Stripe **secret**; solo flujos que abren el **Customer Portal** o Checkout con URLs creadas por el backend.
- El estado de suscripción se lee desde **Firestore** (reglas: solo el propio `uid`).

## Compilar sin servicios Folio Cloud

No necesitas Stripe ni proyecto de pago para desarrollar el editor local:

```bash
flutter pub get
flutter run -d windows
```

Si Firebase no inicializa (sin `firebase_options` o red), la app sigue funcionando en modo local; las funciones Folio Cloud aparecen como no disponibles o desactivadas.
