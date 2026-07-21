/// True si [host] es localhost o una dirección de rango privado (RFC1918),
/// donde enviar credenciales por `http://` sin TLS es un riesgo menor
/// (tráfico que no sale de la máquina/red local). Implementado sin
/// `dart:io` porque los llamadores también compilan para Flutter Web.
bool isPrivateOrLocalHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '::1') return true;
  final parts = h.split('.');
  if (parts.length == 4) {
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    if (a == 127) return true;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
  }
  return false;
}
