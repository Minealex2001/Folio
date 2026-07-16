# Guía para desarrolladores de la Tienda de Apps de Folio

Esta guía explica cómo crear una app para Folio (`.folioapp`) y cómo publicarla en el registry público para que aparezca en la Tienda de Apps.

---

## Índice

1. [¿Qué es una Folio App?](#qué-es-una-folio-app)
2. [Estructura del paquete `.folioapp`](#estructura-del-paquete-folioapp)
3. [El archivo `manifest.json`](#el-archivo-manifestjson)
4. [Crear tu primera app](#crear-tu-primera-app)
5. [Probar la app localmente](#probar-la-app-localmente)
6. [Publicar en el registry](#publicar-en-el-registry)
7. [Actualizar una app publicada](#actualizar-una-app-publicada)
8. [Permisos disponibles](#permisos-disponibles)
9. [Tipos de bloque personalizados](#tipos-de-bloque-personalizados)
10. [Transformadores de IA](#transformadores-de-ia)
11. [Buenas prácticas y seguridad](#buenas-prácticas-y-seguridad)

---

## ¿Qué es una Folio App?

Una Folio App es un paquete que extiende Folio con:

- **Tipos de bloque personalizados**: bloques renderizados en WebView dentro del editor.
- **Comandos de barra `/`**: entradas adicionales en el menú slash del editor.
- **Transformadores de IA**: acciones que procesan bloques o selecciones usando IA (local o API externa).

Las apps se distribuyen como archivos `.folioapp` (un ZIP renombrado).

---

## Estructura del paquete `.folioapp`

```
mi-app.folioapp          ← ZIP renombrado
├── manifest.json        ← REQUERIDO: metadatos y declaración de capacidades
├── icon.png             ← RECOMENDADO: icono 256×256 px, fondo transparente
└── assets/
    ├── block_renderer.html   ← HTML/JS para bloques personalizados (opcional)
    └── ...                   ← cualquier recurso estático necesario
```

> **Nota**: el archivo `.folioapp` es simplemente un ZIP. Puedes crearlo con cualquier herramienta estándar de compresión ZIP y renombrar la extensión.

---

## El archivo `manifest.json`

El `manifest.json` es el único archivo obligatorio. Define la identidad de la app y sus capacidades.

### Esquema completo

```jsonc
{
  // ─── Identidad ───────────────────────────────────────────────────
  "id": "com.tuempresa.nombreapp",      // ID único en formato reverse-domain. INMUTABLE una vez publicado.
  "name": "Nombre de la App",           // Nombre visible en la tienda (máx. 40 caracteres)
  "version": "1.0.0",                   // Semver: MAJOR.MINOR.PATCH
  "author": "Tu Nombre o Empresa",      // Máx. 60 caracteres
  "description": "...",                 // Descripción corta (máx. 200 caracteres)
  "iconUrl": "",                        // URL pública del icono O ruta relativa "assets/icon.png"
  "websiteUrl": "https://ejemplo.com",  // URL de soporte/documentación

  // ─── Permisos ─────────────────────────────────────────────────────
  "permissions": ["internet"],          // Ver sección "Permisos disponibles"

  // ─── Bloques personalizados ───────────────────────────────────────
  "blockTypes": [
    {
      "type": "com.tuempresa.nombreapp.mi_bloque",  // DEBE empezar con el ID de la app
      "label": "Mi Bloque",                         // Texto en el menú slash
      "icon": "widgets",                            // Nombre de icono Material
      "rendererAsset": "assets/block_renderer.html" // HTML a cargar en el WebView
    }
  ],

  // ─── Transformadores de IA ────────────────────────────────────────
  "aiTransformers": [
    {
      "id": "com.tuempresa.nombreapp.resumir",
      "label": "Resumir con mi API",
      "description": "Resume el bloque seleccionado usando la API de ejemplo.",
      "inputType": "block",           // "block" | "selection" | "page"
      "outputType": "replace",        // "replace" | "insert_after" | "clipboard"
      "endpoint": "https://api.ejemplo.com/v1/summarize",  // Requiere permiso "internet"
      "promptTemplate": "Resume el siguiente texto en 3 frases:\n\n{{input}}"
    }
  ]
}
```

### Campos obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `string` | Identificador único. Formato reverse-domain: `com.empresa.app`. **No cambiar** entre versiones. |
| `name` | `string` | Nombre visible. Máx. 40 caracteres. |
| `version` | `string` | Versión semver. Incrementar en cada actualización. |
| `author` | `string` | Autor o empresa. |
| `description` | `string` | Descripción corta. Máx. 200 caracteres. |
| `permissions` | `array` | Lista de permisos solicitados (puede estar vacía `[]`). |

---

## Crear tu primera app

### Paso 1: Crea la estructura de directorios

```
mi-primera-app/
├── manifest.json
├── icon.png
└── assets/
    └── bloque.html
```

### Paso 2: Escribe el `manifest.json`

```json
{
  "id": "com.ejemplo.hola_folio",
  "name": "Hola Folio",
  "version": "1.0.0",
  "author": "Tu Nombre",
  "description": "Mi primera app para Folio con un bloque personalizado.",
  "iconUrl": "assets/icon.png",
  "websiteUrl": "https://github.com/tuusuario/hola-folio",
  "permissions": [],
  "blockTypes": [
    {
      "type": "com.ejemplo.hola_folio.saludo",
      "label": "Saludo",
      "icon": "waving_hand",
      "rendererAsset": "assets/bloque.html"
    }
  ],
  "aiTransformers": []
}
```

### Paso 3: Crea el HTML del bloque (`assets/bloque.html`)

El HTML del bloque se carga en un WebView aislado. Folio inyecta los datos del bloque a través de la interfaz JavaScript `FolioBlock`.

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 12px;
      font-family: system-ui, sans-serif;
      background: transparent;
    }
    .card {
      background: #f0f4ff;
      border-radius: 12px;
      padding: 16px;
    }
  </style>
</head>
<body>
  <div class="card">
    <h3>👋 Hola desde Folio App</h3>
    <p id="contenido">Cargando…</p>
  </div>

  <script>
    // FolioBlock.getData() devuelve el JSON almacenado en el bloque
    window.addEventListener('message', (event) => {
      const msg = JSON.parse(event.data);
      if (msg.type === 'init') {
        const data = msg.data || {};
        document.getElementById('contenido').textContent =
          data.texto || '¡Hola, mundo!';
      }
    });

    // Notifica a Folio que el renderer está listo
    window.parent.postMessage(JSON.stringify({ type: 'ready' }), '*');
  </script>
</body>
</html>
```

### Paso 4: Empaqueta como `.folioapp`

**En Windows (PowerShell):**
```powershell
cd mi-primera-app
Compress-Archive -Path * -DestinationPath ../hola_folio_1.0.0.zip
Rename-Item ../hola_folio_1.0.0.zip hola_folio_1.0.0.folioapp
```

**En macOS / Linux:**
```bash
cd mi-primera-app
zip -r ../hola_folio_1.0.0.folioapp .
```

---

## Probar la app localmente

1. Abre Folio y navega a **Tienda de Apps** (menú lateral o `Ctrl+Shift+A`).
2. Pulsa el botón **Instalar desde archivo** (icono de subida en la barra superior).
3. Selecciona tu archivo `.folioapp`.
4. Confirma la instalación en el diálogo de advertencia.
5. La app aparece en la pestaña **Instaladas**.
6. En el editor, pulsa `/` y busca el nombre de tu bloque para insertarlo.

Para **desinstalar** durante el desarrollo: ve a **Instaladas**, busca tu app y pulsa **Desinstalar**.

---

## Publicar en el registry

El registry público es un archivo JSON hospedado que Folio descarga para mostrar apps en la sección **Community** de la Tienda de Apps.

### Formato del registry (`registry.json`)

```json
{
  "version": 1,
  "apps": [
    {
      "id": "com.ejemplo.hola_folio",
      "name": "Hola Folio",
      "version": "1.0.0",
      "author": "Tu Nombre",
      "description": "Mi primera app para Folio con un bloque personalizado.",
      "iconUrl": "https://cdn.ejemplo.com/hola-folio/icon.png",
      "downloadUrl": "https://cdn.ejemplo.com/hola-folio/hola_folio_1.0.0.folioapp",
      "websiteUrl": "https://github.com/tuusuario/hola-folio",
      "tags": ["bloque", "ejemplo"],
      "permissions": []
    }
  ]
}
```

### Opción A: Registry propio (recomendado para organizaciones)

1. Hospeda el `registry.json` y los archivos `.folioapp` en cualquier servidor HTTPS (GitHub Pages, Cloudflare Pages, S3, etc.).
2. En Folio, ve a **Ajustes → Tienda de Apps** y configura la URL de tu registry.
3. La tienda mostrará tus apps en la sección **Community**.

### Opción B: Registry oficial de la comunidad Folio

Para aparecer en el registry por defecto de Folio:

1. **Haz fork** del repositorio [folio-app-registry](https://github.com/folio-notes/folio-app-registry) en GitHub.
2. **Añade tu entrada** al archivo `registry.json` siguiendo el esquema anterior.
3. **Sube el archivo `.folioapp`** a una URL pública estable (GitHub Releases es una buena opción).
4. **Abre un Pull Request** con:
   - El diff de `registry.json` con tu app añadida.
   - Un icono 256×256 en `icons/<id>.png`.
   - Un breve `README` describiendo qué hace tu app.
5. El equipo de Folio revisará que:
   - El `manifest.json` es válido y los permisos están justificados.
   - El HTML/JS no contiene código malicioso.
   - La URL de descarga es estable.
6. Una vez aprobado y mergeado, tu app aparece en la Tienda de Apps de todos los usuarios.

---

## Actualizar una app publicada

1. Incrementa el campo `version` en `manifest.json` (semver: `1.0.0` → `1.1.0`).
2. Reempaqueta el `.folioapp`.
3. Actualiza la entrada en el `registry.json` (nuevo `version` y nuevo `downloadUrl` si cambia).
4. Si usas el registry oficial, abre un nuevo Pull Request con los cambios.

> Folio **no actualiza apps automáticamente**. El usuario debe desinstalar la versión antigua e instalar la nueva desde la tienda.

---

## Permisos disponibles

| Permiso | Descripción | Cuándo pedirlo |
|---------|-------------|----------------|
| `internet` | Permite que el WebView del bloque y los transformadores hagan peticiones HTTP/HTTPS | Cuando el bloque carga datos externos o el transformador llama a una API |
| `clipboard_read` | Lee el portapapeles del sistema | Solo si tu bloque necesita leer texto copiado |
| `clipboard_write` | Escribe en el portapapeles | Cuando el transformador usa `outputType: "clipboard"` |
| `local_storage` | Persiste datos en el almacenamiento local del dispositivo | Para cachear datos entre sesiones dentro del bloque |

Solicita **únicamente los permisos necesarios**. Apps con permisos excesivos pueden ser rechazadas del registry oficial.

---

## Tipos de bloque personalizados

### Comunicación WebView ↔ Folio

El WebView del bloque y Folio se comunican mediante `postMessage`. Folio envía mensajes al WebView y el WebView puede enviar mensajes de vuelta.

#### Mensajes que Folio envía al bloque

```jsonc
// Inicialización con los datos actuales del bloque
{ "type": "init", "data": { /* objeto JSON guardado en el bloque */ }, "readonly": false }

// El tema cambió (claro/oscuro)
{ "type": "theme_change", "theme": "dark" }

// El bloque fue seleccionado
{ "type": "focus" }
```

#### Mensajes que el bloque puede enviar a Folio

```jsonc
// El renderer terminó de cargar
{ "type": "ready" }

// Actualizar los datos persistidos del bloque
{ "type": "update_data", "data": { /* nuevo objeto JSON */ } }

// Solicitar al usuario que abra un diálogo (Folio lo gestionará)
{ "type": "request_edit" }

// Notificar la altura deseada del bloque (en píxeles)
{ "type": "resize", "height": 240 }
```

### Ejemplo de bloque interactivo

```javascript
// En el HTML del bloque
let blockData = {};

window.addEventListener('message', (event) => {
  const msg = JSON.parse(event.data);
  
  if (msg.type === 'init') {
    blockData = msg.data || { count: 0 };
    render();
  }
});

function increment() {
  blockData.count = (blockData.count || 0) + 1;
  render();
  // Persistir en Folio
  window.parent.postMessage(
    JSON.stringify({ type: 'update_data', data: blockData }),
    '*'
  );
}

function render() {
  document.getElementById('count').textContent = blockData.count || 0;
}

window.parent.postMessage(JSON.stringify({ type: 'ready' }), '*');
```

---

## Transformadores de IA

Los transformadores de IA aparecen en el menú contextual de bloques y permiten procesarlos con IA.

### Tipos de entrada (`inputType`)

| Valor | Descripción |
|-------|-------------|
| `block` | El texto completo del bloque activo |
| `selection` | El texto seleccionado dentro de un bloque |
| `page` | Todo el texto de la página actual |

### Tipos de salida (`outputType`)

| Valor | Descripción |
|-------|-------------|
| `replace` | Reemplaza el contenido del bloque/selección con el resultado |
| `insert_after` | Inserta el resultado en un nuevo bloque después del actual |
| `clipboard` | Copia el resultado al portapapeles sin modificar el editor |

### Plantillas de prompt

El campo `promptTemplate` soporta la variable `{{input}}` que Folio sustituye por el texto de entrada:

```json
"promptTemplate": "Traduce al inglés el siguiente texto. Responde solo con la traducción:\n\n{{input}}"
```

### Uso de API externa

Si el transformador usa una API externa (`endpoint`), Folio hará una petición POST con el siguiente cuerpo:

```json
{
  "prompt": "<prompt con {{input}} sustituido>",
  "model": "<modelo configurado por el usuario, si aplica>"
}
```

Folio espera una respuesta JSON con el campo `result`:

```json
{
  "result": "Texto transformado por la API..."
}
```

---

## Buenas prácticas y seguridad

### Seguridad

- **No solicites permisos innecesarios.** Cada permiso requiere aprobación del usuario.
- **No almacenes credenciales en el paquete.** Usa configuración externa o pide al usuario que las introduzca.
- **Valida todas las entradas** en el HTML/JS del bloque antes de procesarlas.
- **Usa HTTPS** para todos los recursos y endpoints externos.
- **No hagas peticiones a terceros sin que el usuario lo sepa.** Documenta claramente qué datos se envían y a dónde.

### Calidad

- Mantén el `manifest.json` actualizado con la versión correcta en cada release.
- El campo `id` es **inmutable**. Nunca lo cambies entre versiones; si lo cambias, Folio lo tratará como una app diferente.
- Proporciona un icono claro y representativo (256×256 px, fondo transparente o blanco).
- Escribe una descripción concisa que explique claramente qué hace la app.
- Incluye una `websiteUrl` con documentación o código fuente.

### Compatibilidad

- Testa la app en las plataformas soportadas por Folio: Windows, macOS, Linux, Android, iOS.
- El WebView del bloque usa el motor del sistema (WebView2 en Windows, WKWebView en macOS/iOS, WebView en Android). Evita APIs del navegador no ampliamente soportadas.
- No dependas de características CSS/JS experimentales.

---

*Última actualización: abril 2026*
