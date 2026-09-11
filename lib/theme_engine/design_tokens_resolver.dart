import '../config/models/design_tokens.dart';
import '../config/models/design_variables.dart';
import '../config/models/token_ref.dart';

/// Máximo de saltos `var.` -> `var.` -> ... antes de caer al fallback —
/// límite explícito para que una cadena de variables nunca sea más profunda
/// de lo que alguien pueda depurar a ojo (Fase 12, tras feedback directo).
const int kMaxVariableChainDepth = 4;

/// Resuelve [TokenRef]s contra [DesignTokens]/[DesignVariables]. Es el único
/// camino de código que entiende tanto referencias directas a token
/// (`"radius.lg"`) como cadenas de variable (`"var.editorPadding"`) — cada
/// fase posterior (Component Styles, States, Layers, Semantic Colors) llama
/// aquí en vez de reimplementar su propio lookup.
class DesignTokensResolver {
  const DesignTokensResolver(this.tokens, this.variables);

  final DesignTokens tokens;
  final DesignVariables variables;

  double resolveDouble(TokenRef<double> ref, double fallback) => _resolve<double>(
    ref.isReference ? ref.refName! : null,
    ref.literalValue,
    fallback,
    lookup: _lookupDouble,
    seen: {},
    depth: 0,
  );

  int resolveColor(TokenRef<int> ref, int fallback) => _resolve<int>(
    ref.isReference ? ref.refName! : null,
    ref.literalValue,
    fallback,
    lookup: _lookupColor,
    seen: {},
    depth: 0,
  );

  T _resolve<T>(
    String? refName,
    T? literal,
    T fallback, {
    required T? Function(String) lookup,
    required Set<String> seen,
    required int depth,
  }) {
    if (refName == null) return literal ?? fallback;
    if (seen.contains(refName)) return fallback; // guarda contra ciclos
    if (depth >= kMaxVariableChainDepth) return fallback; // guarda contra cadenas demasiado largas
    seen.add(refName);
    if (refName.startsWith('var.')) {
      final varName = refName.substring(4);
      final nextRef = variables.entries[varName];
      if (nextRef == null) return fallback;
      final nextName = nextRef.startsWith('@') ? nextRef.substring(1) : nextRef;
      return _resolve<T>(
        nextName,
        null,
        fallback,
        lookup: lookup,
        seen: seen,
        depth: depth + 1,
      );
    }
    return lookup(refName) ?? fallback;
  }

  double? _lookupDouble(String refName) {
    final parts = refName.split('.');
    if (parts.length != 2) return null;
    switch (parts[0]) {
      case 'radius':
        return tokens.radius[parts[1]];
      case 'space':
        return tokens.space[parts[1]];
      case 'opacity':
        return tokens.opacity[parts[1]];
      case 'size':
        return tokens.size[parts[1]];
      default:
        return null;
    }
  }

  int? _lookupColor(String refName) {
    final parts = refName.split('.');
    return parts.length == 2 && parts[0] == 'color' ? tokens.color[parts[1]] : null;
  }
}
