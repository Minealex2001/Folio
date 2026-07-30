/// Ejecuta [task] sobre cada elemento de [items] con como mucho
/// [concurrency] tareas en vuelo a la vez, en vez de una tras otra.
///
/// Los resultados se devuelven en el mismo orden que [items],
/// independientemente del orden real de finalización — importante cuando el
/// llamador reconstruye algo posicional (p. ej. páginas de una libreta) a
/// partir de la lista de resultados.
///
/// Pensado para llamadas de red N+1 (una por página/adjunto/blob) donde la
/// latencia de cada request domina el tiempo total: acotar la concurrencia
/// da paralelismo real sin abrir cientos de conexiones a la vez.
Future<List<R>> mapConcurrent<T, R>(
  List<T> items,
  Future<R> Function(T item) task, {
  int concurrency = 4,
}) async {
  if (items.isEmpty) return const [];
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  final workerCount = concurrency < 1
      ? 1
      : (concurrency > items.length ? items.length : concurrency);

  Future<void> worker() async {
    while (true) {
      final i = nextIndex;
      if (i >= items.length) return;
      nextIndex++;
      results[i] = await task(items[i]);
    }
  }

  await Future.wait(List.generate(workerCount, (_) => worker()));
  return List<R>.from(results);
}
