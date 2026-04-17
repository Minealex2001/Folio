# Catálogo Stripe (Folio Cloud)

Crear estos productos y precios en el [Dashboard de Stripe](https://dashboard.stripe.com) (modo **test** primero). En las variables de entorno puedes poner cada **Price ID** (`price_...`) o, si solo usas el producto, el **Product ID** (`prod_...`). En ese caso el producto debe tener un **precio por defecto** (Stripe Dashboard → producto → marcar default price); el backend lo resuelve a `price_...` para Checkout y reconoce los pagos en el webhook por producto.

| Oferta | Tipo | Precio | Entrega |
|--------|------|--------|---------|
| Folio Cloud | Suscripción mensual | 4,99 € | Sync en la nube + 500 gotas/mes (recarga día 1, ver `monthlyInkRefill`) |
| Tintero pequeño | Pago único | 1,99 € | +300 gotas (no caducan) |
| Tintero mediano | Pago único | 4,99 € | +1.000 gotas |
| Tintero grande | Pago único | 9,99 € | +2.500 gotas |
| Librería pequeña (copias) | Suscripción mensual | 1,99 €/mes | +20 GB mientras esté activa (`STRIPE_PRICE_BACKUP_STORAGE_PACK_SMALL`) |
| Librería mediana (copias) | Suscripción mensual | 4,99 €/mes | +75 GB (`STRIPE_PRICE_BACKUP_STORAGE_PACK_MEDIUM`) |
| Librería grande (copias) | Suscripción mensual | 9,99 €/mes | +250 GB (`STRIPE_PRICE_BACKUP_STORAGE_PACK_LARGE`) |

## Suscripción mensual y features

El precio recurrente **Folio Cloud** debe mapear en el webhook a `folioCloud.features` con las tres banderas activas: **backup** (ZIP cifrado en Storage), **cloudAi** (callable con gotas) y **publishWeb** (subida a `published/` + documentos en `publishedPages`). La app usa esas banderas para habilitar UI y servicios; Storage/Firestore rules y las callables siguen validando en servidor.

Flujos concretos: copia manual y opcionalmente la copia programada tras export local; publicación desde el workspace y gestión de páginas publicadas en Ajustes; selector de IA Folio Cloud cuando el plan lo permite. Detalle técnico del backend: [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md).

## Webhook

Configura el endpoint HTTPS de la función `stripeWebhook` y el secreto `STRIPE_WEBHOOK_SECRET`.

Eventos mínimos: `checkout.session.completed`, `checkout.session.async_payment_succeeded` (pagos diferidos / segundo aviso), `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted` (los de suscripción rellenan `stripeCustomerId` si el checkout no lo hizo).

En el webhook se usa `metadata.firebase_uid` y, si falta, `client_reference_id` (Folio lo envía con tu `uid` de Firebase).

## Checkout

La app abre **Stripe Checkout** vía la callable `createCheckoutSession` (no hay claves secretas en el cliente).
