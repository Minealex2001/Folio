# Folio Cloud — entorno staging

Hay dos proyectos Firebase:

| Alias (`.firebaserc`) | Project ID | Uso |
|---|---|---|
| `production` / `folio` / `default` | `folio-minealexgames` | Producción |
| `staging` | `folio-staging-minealex` | Pruebas de backend (no producción) |

## Qué hace un deploy

- **`npm run deploy`** / **`deploy:production`** (en `functions/`): sube **solo Cloud Functions** a **producción**.
- **`npm run deploy:staging`**: sube **solo Functions** a **staging**.
- **`npm run deploy:staging:backend`**: Functions + reglas Firestore + reglas Storage a **staging**.

Nunca uses `firebase deploy` sin `--project` si no estás seguro del proyecto activo. Los scripts de `package.json` fijan el destino.

Desde la raíz del repo (PowerShell):

```powershell
# Backend completo a staging (recomendado para probar)
npx -y firebase-tools@latest deploy --only functions,firestore:rules,storage --project staging

# Solo functions a staging
cd functions; npm run deploy:staging

# Functions a producción (explícito)
cd functions; npm run deploy:production
```

## Cliente Flutter apuntando a staging

Compila/ejecuta con:

```powershell
flutter run -d windows --dart-define=FOLIO_FIREBASE_ENV=staging
```

Sin el define (o con `production`) la app sigue usando `folio-minealexgames`.

Archivos:

- [`lib/firebase_options.dart`](../lib/firebase_options.dart) — producción
- [`lib/firebase_options_staging.dart`](../lib/firebase_options_staging.dart) — staging
- [`lib/config/folio_firebase_env.dart`](../lib/config/folio_firebase_env.dart) — selección por `FOLIO_FIREBASE_ENV`

Android staging usa el package `com.minealexgames.folio.staging` (app registrada en el proyecto staging). El `google-services.json` de producción **no** se sobrescribe; hace falta un product flavor si quieres builds Android staging en CI.

## Primera vez en staging (checklist)

1. En [Firebase Console → Folio Staging](https://console.firebase.google.com/project/folio-staging-minealex):
   - Activar **Authentication** (Email/Password y/o Google, según uses en prod).
   - Crear base **Firestore** (modo producción + las reglas del repo).
   - Crear bucket **Storage** por defecto.
   - Plan **Blaze** (necesario para Cloud Functions).
2. Copiar secretos/variables de Functions desde prod **solo** los que necesites probar (Stripe test keys, `OPENAI_API_KEY`, etc.) — no reutilices webhooks de producción apuntando a staging sin un endpoint distinto.
3. Desplegar: `npm run deploy:staging:backend` desde `functions/`.
4. Arrancar la app con `--dart-define=FOLIO_FIREBASE_ENV=staging` y crear una cuenta de prueba en ese proyecto.

## Relación con la migración vault v1 (árbol)

La migración blob→tree es **local al cliente**. Staging sirve para validar callables/sync/backups contra un backend aislado; no sustituye probar el formato `repo/` + `versions/` en disco.
