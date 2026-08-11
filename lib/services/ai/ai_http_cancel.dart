import 'dart:io';

import 'ai_cancel_token.dart';

/// Enlaza [token] con [client] para que un Stop cierre la conexión en curso.
///
/// Devuelve un disposer que hay que llamar en `finally` (quita el listener).
void Function() attachHttpClientCancel(AiCancelToken? token, HttpClient client) {
  if (token == null) return () {};
  void onCancel() {
    try {
      client.close(force: true);
    } catch (_) {}
  }
  token.addOnCancel(onCancel);
  return () => token.removeOnCancel(onCancel);
}

/// Si [token] ya está cancelado, o [error] llegó tras cancelar, lanza
/// [AiRequestCancelledException]; si no, re-lanza [error].
Never rethrowUnlessCancelled(AiCancelToken? token, Object error) {
  if (token?.isCancelled == true || error is AiRequestCancelledException) {
    throw const AiRequestCancelledException();
  }
  throw error;
}
