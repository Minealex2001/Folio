import 'dart:html' as html;

/// Hostname de la página actual (sin puerto), p. ej. `folio.com.es`
/// o `localhost` en desarrollo.
String currentWebHost() => html.window.location.hostname ?? 'localhost';
