import 'package:http/http.dart' as http;

/// Cliente HTTP compartido para todas las llamadas a Folio Cloud.
///
/// Las funciones top-level de `package:http` (`http.get`, `http.post`, ...)
/// crean y cierran un `http.Client` nuevo en cada llamada, lo que obliga a
/// repetir el handshake TCP+TLS por request. Reutilizar un ├║nico cliente
/// permite mantener conexiones keep-alive por host, lo que importa mucho
/// en redes con m├ís latencia (VPN/proxy corporativo).
final http.Client folioCloudHttpClient = http.Client();
