# Configurar Stripe con Folio (Cloud Functions)

No puedes poner claves secretas en el repositorio. Todo va en **`functions/.env`** (local) o en **Secret Manager / variables de entorno** del proyecto GCP al desplegar.

## 1. Archivo `functions/.env`

Copia la plantilla y rellena con tus valores reales:

```bash
cp functions/.env.example functions/.env
```

| Variable | Obligatorio | Descripción |
|----------|-------------|-------------|
| `STRIPE_SECRET_KEY` | Sí | `sk_test_...` o `sk_live_...` (Dashboard → Developers → API keys) |
| `STRIPE_WEBHOOK_SECRET` | Sí en producción | `whsec_...` del endpoint de webhook (ver §3) |
| `STRIPE_PRICE_FOLIO_CLOUD_MONTHLY` | Sí | Price ID de la suscripción 4,99 €/mes |
| `STRIPE_PRICE_INK_SMALL` / `MEDIUM` / `LARGE` | Sí para tinteros | Price IDs de pagos únicos |
| `BILLING_PORTAL_RETURN_URL` | Recomendado | URL a la que vuelve el usuario tras el portal de facturación |
| `STRIPE_CHECKOUT_SUCCESS_URL` / `STRIPE_CHECKOUT_CANCEL_URL` | Opcional | Tras Checkout; si faltan, se reutiliza `BILLING_PORTAL_RETURN_URL` |

Los `price_...` salen de **Stripe Dashboard → Productos → [producto] → Precios**.

## 2. Comprobar que Functions lee el `.env`

Las funciones cargan `functions/.env` al arrancar (ver `loadEnv` en `functions/src/index.ts`).

Emulador:

```bash
cd functions && npm run build && cd .. && firebase emulators:start --only functions
```

## 3. Webhook (Stripe → `stripeWebhook`)

1. Despliega las functions: `firebase deploy --only functions`.
2. En Stripe Dashboard → **Developers → Webhooks → Add endpoint**:
   - URL: `https://<region>-<project>.cloudfunctions.net/stripeWebhook` (la URL exacta sale en Firebase Console → Functions).
   - Eventos: al menos `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`.
3. Copia el **Signing secret** (`whsec_...`) a `STRIPE_WEBHOOK_SECRET` en `.env` o en secretos de producción y vuelve a desplegar.

**Desarrollo local:** usa [Stripe CLI](https://stripe.com/docs/stripe-cli):

```bash
stripe listen --forward-to http://127.0.0.1:5001/<project-id>/<region>/stripeWebhook
```

La CLI mostrará un `whsec_...` **temporal** para pegar en `STRIPE_WEBHOOK_SECRET` mientras pruebas.

## 4. Producción (sin subir `.env` a Git)

Opciones habituales:

- **Firebase / Google Cloud**: definir variables en la configuración de Cloud Functions (o Secret Manager) con los mismos nombres que en `.env`.
- Vuelve a ejecutar `firebase deploy --only functions` tras cambiar secretos.

## 5. URL tras pagar (éxito)

Stripe redirige al navegador a `STRIPE_CHECKOUT_SUCCESS_URL` o `BILLING_PORTAL_RETURN_URL` (p. ej. `https://folio.no/`). Eso **no abre la app de escritorio**; el estado en la app viene de **Firestore** cuando el webhook `checkout.session.completed` escribe en `users/{uid}`. Si tarda o falla el webhook, en Ajustes → Folio Cloud usa **«Actualizar estado desde Stripe»** (callable `syncFolioCloudSubscriptionFromStripe`). Conviene una página de éxito breve (“Puedes volver a Folio”) en esa URL.

## 6. Cliente Flutter

No añadas claves de Stripe en Dart. La app abre Checkout/portal con las callables y puede forzar sync con `syncFolioCloudSubscriptionFromStripe`.
