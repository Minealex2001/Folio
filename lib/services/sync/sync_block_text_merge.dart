import 'package:diff_match_patch/diff_match_patch.dart';

/// Origen elegido para un hunk de merge.
enum SyncMergeHunkChoice { local, remote, both }

/// Tipo de hunk tras agrupar el diff local vs remoto.
enum SyncMergeHunkKind { equal, insert, delete, replace }

/// Trozo de diff seleccionable (estilo merge de Git).
class SyncMergeHunk {
  const SyncMergeHunk({
    required this.kind,
    required this.localText,
    required this.remoteText,
  });

  final SyncMergeHunkKind kind;
  final String localText;
  final String remoteText;

  bool get isConflict =>
      kind == SyncMergeHunkKind.replace ||
      kind == SyncMergeHunkKind.insert ||
      kind == SyncMergeHunkKind.delete;
}

/// Diff de texto plano y merge por hunks con `diff_match_patch`.
class SyncBlockTextMerge {
  const SyncBlockTextMerge._();

  static List<SyncMergeHunk> buildHunks(String localText, String remoteText) {
    final dmp = DiffMatchPatch()..diffTimeout = 0;
    final diffs = dmp.diff(localText, remoteText, true);
    dmp.diffCleanupSemantic(diffs);
    return _groupDiffs(diffs);
  }

  static List<SyncMergeHunk> _groupDiffs(List<Diff> diffs) {
    final out = <SyncMergeHunk>[];
    var i = 0;
    while (i < diffs.length) {
      final cur = diffs[i];
      if (cur.operation == DIFF_EQUAL) {
        out.add(
          SyncMergeHunk(
            kind: SyncMergeHunkKind.equal,
            localText: cur.text,
            remoteText: cur.text,
          ),
        );
        i++;
        continue;
      }
      if (cur.operation == DIFF_DELETE &&
          i + 1 < diffs.length &&
          diffs[i + 1].operation == DIFF_INSERT) {
        out.add(
          SyncMergeHunk(
            kind: SyncMergeHunkKind.replace,
            localText: cur.text,
            remoteText: diffs[i + 1].text,
          ),
        );
        i += 2;
        continue;
      }
      if (cur.operation == DIFF_INSERT &&
          i + 1 < diffs.length &&
          diffs[i + 1].operation == DIFF_DELETE) {
        out.add(
          SyncMergeHunk(
            kind: SyncMergeHunkKind.replace,
            localText: diffs[i + 1].text,
            remoteText: cur.text,
          ),
        );
        i += 2;
        continue;
      }
      if (cur.operation == DIFF_DELETE) {
        out.add(
          SyncMergeHunk(
            kind: SyncMergeHunkKind.delete,
            localText: cur.text,
            remoteText: '',
          ),
        );
        i++;
        continue;
      }
      // DIFF_INSERT
      out.add(
        SyncMergeHunk(
          kind: SyncMergeHunkKind.insert,
          localText: '',
          remoteText: cur.text,
        ),
      );
      i++;
    }
    return out;
  }

  /// Construye el texto fusionado según la elección por hunk.
  /// En [SyncMergeHunkChoice.both], el orden sigue el del diff (local luego remoto
  /// en replace/delete; remoto solo en insert; local solo en delete).
  static String buildMergedPlainText(
    List<SyncMergeHunk> hunks,
    List<SyncMergeHunkChoice> choices,
  ) {
    assert(hunks.length == choices.length);
    final buf = StringBuffer();
    for (var i = 0; i < hunks.length; i++) {
      final h = hunks[i];
      final c = choices[i];
      if (h.kind == SyncMergeHunkKind.equal) {
        buf.write(h.localText);
        continue;
      }
      switch (c) {
        case SyncMergeHunkChoice.local:
          buf.write(h.localText);
        case SyncMergeHunkChoice.remote:
          buf.write(h.remoteText);
        case SyncMergeHunkChoice.both:
          buf.write(h.localText);
          buf.write(h.remoteText);
      }
    }
    return buf.toString();
  }

  /// Elecciones por defecto: remoto en conflictos (como “aceptar trozos remotos”).
  static List<SyncMergeHunkChoice> defaultChoices(List<SyncMergeHunk> hunks) {
    return [
      for (final h in hunks)
        h.isConflict
            ? SyncMergeHunkChoice.remote
            : SyncMergeHunkChoice.local,
    ];
  }
}
