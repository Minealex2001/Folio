import 'dart:async';

import '../../core/errors/folio_exception.dart';

class SpotifyAuthCancelledException extends FolioException {
  const SpotifyAuthCancelledException()
      : super('OAuth cancelado por el usuario.');
}

class SpotifyAuthCancelToken {
  final Completer<void> _c = Completer<void>();
  bool get isCancelled => _c.isCompleted;
  Future<void> get whenCancelled => _c.future;
  void cancel() {
    if (!_c.isCompleted) _c.complete();
  }
}
