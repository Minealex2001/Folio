# Windows: bandeja del sistema frente a barra de tareas

Folio usa **tray_manager** para el icono en la **bandeja del sistema** (área de notificación, junto al reloj). El menú contextual **Abrir / Buscar / Bloquear / Cerrar aplicación** se asocia a ese icono.

El botón de la aplicación en la **barra de tareas** de Windows (la fila de ventanas abiertas) lo gestiona el shell; un menú personalizado ahí (tipo Jump List nativa) no está integrado en Folio y requeriría código Win32 aparte.

Para minimizar a bandeja al pasar al segundo plano, usa **Ajustes → Escritorio → Minimizar a bandeja**.
