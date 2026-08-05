import 'package:json_annotation/json_annotation.dart';

/// O bien un literal [T], o una referencia por nombre a
/// [DesignTokens]/[DesignVariables] (ver `theme_engine/design_tokens_resolver.dart`).
///
/// Formato de cable: un literal se codifica exactamente como el JSON normal
/// de [T] (un número desnudo para `double`, un entero para ARGB) — idéntico
/// byte a byte a un campo crudo de hoy. Una referencia se codifica como un
/// string con prefijo `@`, ej. `"@radius.lg"` o `"@var.editorPadding"`. Como
/// los documentos guardados antiguos solo contienen literales desnudos, esto
/// es 100% retrocompatible sin necesitar migración.
class TokenRef<T> {
  const TokenRef.literal(T value) : _value = value, refName = null;
  const TokenRef.ref(String name) : _value = null, refName = name;

  final T? _value;
  final String? refName;

  bool get isReference => refName != null;
  T? get literalValue => _value;

  @override
  bool operator ==(Object other) =>
      other is TokenRef<T> &&
      other.refName == refName &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(refName, _value);

  @override
  String toString() =>
      isReference ? 'TokenRef.ref($refName)' : 'TokenRef.literal($_value)';
}

/// Codifica/decodifica `TokenRef<double>` para json_serializable — usado por
/// campos de radio/espaciado/opacidad que pueden ser un literal o una
/// referencia de token.
class TokenRefDoubleConverter implements JsonConverter<TokenRef<double>, Object?> {
  const TokenRefDoubleConverter();

  @override
  TokenRef<double> fromJson(Object? json) {
    if (json is String && json.startsWith('@')) {
      return TokenRef<double>.ref(json.substring(1));
    }
    return TokenRef<double>.literal((json as num).toDouble());
  }

  @override
  Object? toJson(TokenRef<double> ref) =>
      ref.isReference ? '@${ref.refName}' : ref.literalValue;
}

/// Igual que [TokenRefDoubleConverter] pero para valores enteros ARGB.
class TokenRefIntConverter implements JsonConverter<TokenRef<int>, Object?> {
  const TokenRefIntConverter();

  @override
  TokenRef<int> fromJson(Object? json) {
    if (json is String && json.startsWith('@')) {
      return TokenRef<int>.ref(json.substring(1));
    }
    return TokenRef<int>.literal((json as num).toInt());
  }

  @override
  Object? toJson(TokenRef<int> ref) =>
      ref.isReference ? '@${ref.refName}' : ref.literalValue;
}

/// Variante nullable de [TokenRefDoubleConverter] — para campos `TokenRef<double>?`.
class NullableTokenRefDoubleConverter
    implements JsonConverter<TokenRef<double>?, Object?> {
  const NullableTokenRefDoubleConverter();

  @override
  TokenRef<double>? fromJson(Object? json) {
    if (json == null) return null;
    return const TokenRefDoubleConverter().fromJson(json);
  }

  @override
  Object? toJson(TokenRef<double>? ref) =>
      ref == null ? null : const TokenRefDoubleConverter().toJson(ref);
}

/// Variante nullable de [TokenRefIntConverter] — para campos `TokenRef<int>?`.
class NullableTokenRefIntConverter
    implements JsonConverter<TokenRef<int>?, Object?> {
  const NullableTokenRefIntConverter();

  @override
  TokenRef<int>? fromJson(Object? json) {
    if (json == null) return null;
    return const TokenRefIntConverter().fromJson(json);
  }

  @override
  Object? toJson(TokenRef<int>? ref) =>
      ref == null ? null : const TokenRefIntConverter().toJson(ref);
}
