# Folio — Cumplimiento EU AI Act (transparencia)

Documento técnico para usuarios y revisores. Describe las funciones de IA de Folio, su nivel de riesgo según el Reglamento (UE) 2024/1689 (AI Act), proveedores, datos tratados y cómo desactivarlas.

Última revisión: 2026-08-03.

---

## Resumen

| Función | Riesgo IA Act | Proveedores | Datos típicos | Uso |
| --- | --- | --- | --- | --- |
| Chat Quill / tools / Plan | Limitado (transparencia Art. 50) | Ollama, LM Studio, Quill Cloud→OpenAI, BYOK OpenAI/Gemini, Gemini Nano | Prompt, historial, contexto de páginas (`@`), tools; cloud sin adjuntos binarios | Resumir, generar, editar, clasificar vía tools |
| Propiedades BD `aiGenerated` | Limitado | Mismo runtime Quill | Texto de fila / prompt | Generar valor de celda |
| Copilot experimental | Limitado | Mismo | Contexto del editor | Autocompletar |
| Notas de reunión (STT) | Limitado | Whisper.cpp local / OpenAI `gpt-4o-transcribe` (+ chat para etiquetar speakers) | Audio chunks / texto | Transcribir + etiquetas `Speaker N` |
| Generación de imágenes | Limitado (transparencia reforzada Art. 50(2), contenido sintético) | Quill Cloud→OpenAI, BYOK OpenAI/compatible local | Prompt + contexto de página opcional (solo si el usuario lo activa); imagen generada (bytes) | Generar una imagen desde un prompt, mostrarla en el chat, insertarla como bloque si el usuario lo decide |
| MCP (si activo) | Limitado + allowlist | Cliente externo | Según tool | Integración |

**No hay** análisis de emociones, tono afectivo ni biometría de identidad en el producto.

Quill está **apagado por defecto** (`aiEnabled = false`). Al activarlo se muestra un diálogo de consentimiento (uso de IA + alcance global de la app).

---

## 1. Descripción de cada función

### 1.1 Asistente Quill (chat, Plan, tools)

Panel de chat en el workspace. El header muestra el subtítulo fijo **«Asistente IA»**. Puede usar páginas adjuntas con `@`, herramientas in-app y modo Plan.

### 1.2 Contexto `@`

Al mencionar una página, Quill incluye texto de esa página en el prompt (límites de tamaño en sesión). La UI indica: **«Mención de IA – analiza contenido de esta página»**.

### 1.3 Contenido generado en el vault

Los bloques materializados por Quill llevan `aiGenerated: true` y un icono sutil en el editor. Si el usuario edita el texto, se limpia la marca.

### 1.4 Notas de reunión (`meeting_note`, beta)

Pipeline: grabación → STT (local Whisper o Quill Cloud) → diarización de hablantes (`Speaker 1`, `Speaker 2`, …).

- **Incluye:** texto transcrito y separación aproximada de turnos.
- **No incluye:** emociones, sentimiento, tono afectivo ni voiceprint / identidad biométrica.
- Rasgos acústicos locales (energía, ZCR) solo sirven para estimar cambios de turno, no para categorizar atributos sensibles.

**Veredicto de riesgo:** limitado; basta transparencia y documentación (este archivo + etiquetado de Quill cuando se use el transcript en el chat).

### 1.5 MCP e integraciones

Servidor/cliente MCP opt-in, con allowlist y diálogos de aprobación. Fuera del núcleo de inferencia Quill, pero puede exponer tools al mismo catálogo.

### 1.6 Generación de imágenes

Quill puede generar una imagen a partir de un prompt de texto, opcionalmente combinado con el contenido de la página actual (solo si el usuario activa el toggle **«Usar contexto de la página actual»** — desactivado por defecto). Dos caminos de entrada: pedirlo conversacionalmente en el chat (tool `generate_image`), o el botón dedicado **«Generar imagen»** del compositor.

La imagen se muestra siempre primero en el chat, con el chip **«Generado por IA»** visible; el usuario decide si pulsar **«Insertar en la página»** para materializarla como bloque `image` (que también lleva `aiGenerated: true`, ver §1.3).

**Veredicto de riesgo:** limitado, pero el Art. 50(2) del AI Act exige para contenido sintético (imagen/audio/vídeo generado) una transparencia **más estricta** que para texto: la marca debe ser tanto legible por máquina (`aiGenerated: true` en el bloque) como perceptible por la persona usuaria (chip visible en la tarjeta de chat y en el editor). Ambas condiciones están cubiertas por el diseño actual.

**Proveedores:** Quill Cloud (backend → API de imágenes de OpenAI, modelo configurable vía panel de administración, cobra tinta) o BYOK con un endpoint OpenAI-compatible (incluye servidores locales tipo LocalAI/ComfyUI-shim). `ollama`/`lmStudio` no exponen generación de imágenes hoy y reportan un error claro en vez de fallar en silencio.

**Datos:** a diferencia del chat (que no envía adjuntos binarios, ver §3), esta operación sí genera y devuelve una imagen — es una llamada dedicada (`/api/v1/ai/generate-image`), no una variante de `complete`.

---

## 2. Proveedores de modelos

| `AiProvider` | Dónde corre | Notas |
| --- | --- | --- |
| `ollama` / `lmStudio` | Localhost (escritorio) | Los datos no salen del dispositivo por defecto |
| `quillCloud` | Backend Folio → OpenAI | Requiere cuenta / tinta; chat vía `/api/v1/ai/*` |
| `openAi` / `gemini` | Endpoint + API key del usuario (BYOK) | El usuario elige el destino |
| `geminiNano` | On-device (Android) | Inferencia en el dispositivo |

Modelos cloud por defecto (backend, configurables por entorno o desde el panel de administración): chat OpenAI (`OPENAI_MODEL`), transcripción (`OPENAI_TRANSCRIBE_MODEL`, p. ej. `gpt-4o-transcribe`), generación de imágenes (`OPENAI_IMAGE_MODEL`, por defecto `gpt-image-2-2026-04-21`).

---

## 3. Privacidad y datos

- **Opt-in:** Ajustes → Quill → Activar Quill.
- **Local-first:** Ollama / LM Studio / Gemini Nano no envían prompts a Folio Cloud.
- **Quill Cloud:** envía prompt, system prompt, mensajes y tools al backend; **no** adjuntos de archivo/imagen en `complete`. Transcripción cloud envía audio. La generación de imágenes usa un endpoint dedicado (`/ai/generate-image`, no `complete`) que sí devuelve bytes de imagen.
- **Endpoint remoto BYOK:** requiere confirmación explícita si el host no es localhost (`AiSafetyPolicy`).
- **Telemetría:** independiente de Quill; ver [TELEMETRY.md](TELEMETRY.md).

---

## 4. Cómo desactivar la IA

1. Abrir **Ajustes → Quill**.
2. Desactivar **Activar Quill**.

Eso deshabilita chat, contexto `@`, Copilot experimental y generación bajo demanda de propiedades IA. Las notas de reunión pueden seguir grabando audio; la transcripción local/cloud se controla en el bloque / ajustes de meeting note.

También hay un acceso desde **Ajustes → Privacidad** hacia la sección Quill y un ítem **Documentación de IA** con este resumen.

---

## 5. Capacidades y límites

- Los modelos pueden alucinar; el usuario debe revisar el contenido insertado.
- Quill no sustituye consejo legal, médico ni financiero.
- La diarización de speakers es aproximada.
- El etiquetado `aiGenerated` en bloques se pierde al editar a mano (contenido ya humano).

---

## 6. Referencias en el producto

- UI: subtítulo «Asistente IA», hint de mención `@`, icono «Generado por IA».
- Ajustes → Quill → Documentación de IA.
- [FEATURES.md](FEATURES.md) §20 (meeting notes), §23–24 (Quill / `@`, incluida generación de imágenes).
- Política web: [Política de privacidad](https://minealexgames.com/es/privacy-policy) (`https://minealexgames.com/{lang}/privacy-policy`).

---

## Apéndice — Texto sugerido para la política de privacidad (sección IA)

Puedes copiar y adaptar lo siguiente en [minealexgames.com/…/privacy-policy](https://minealexgames.com/es/privacy-policy):

> **Asistente de IA (Quill) y notas de reunión**
>
> Folio ofrece un asistente de IA opcional llamado Quill. Está desactivado por defecto. Al activarlo, confirmas que la función usa sistemas de IA y que Quill es un ajuste a nivel de aplicación.
>
> **Proveedores.** Puedes usar modelos locales (p. ej. Ollama o LM Studio en tu equipo), inferencia en el dispositivo (Gemini Nano en Android compatible), Quill Cloud (que reenvía solicitudes a OpenAI a través de los servidores de Folio) o tu propia clave API (OpenAI / Gemini) hacia el endpoint que configures.
>
> **Datos.** Según el proveedor, podemos procesar el texto de tus mensajes, el historial del hilo y el contenido de las páginas que adjuntes como contexto. Con Quill Cloud no se envían adjuntos de archivo o imagen en las completaciones de chat. Si usas transcripción en la nube para notas de reunión, se envían fragmentos de audio para obtener texto. La transcripción local se ejecuta en tu máquina. Las notas de reunión generan texto y etiquetas de hablante; no analizamos emociones ni rasgos biométricos de identidad. Si pides a Quill generar una imagen, tu descripción (y, solo si lo activas, el contenido de la página actual) se envía al proveedor de imágenes elegido para producir la imagen, que se te muestra en el chat antes de que decidas insertarla en tu libreta; las imágenes generadas se marcan como contenido de IA.
>
> **Finalidad.** Ayudarte a resumir, generar, editar y organizar contenido de tus libretas, y a transcribir reuniones.
>
> **Control.** Puedes desactivar Quill en cualquier momento en Ajustes. Más detalle técnico: documentación de cumplimiento de IA en la aplicación y en el repositorio (`docs/AI_COMPLIANCE.md`).
