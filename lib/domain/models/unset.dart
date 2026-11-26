/// Sentinela usada nos `copyWith` para permitir "limpar" campos anuláveis
/// (passar `null` explicitamente) sem confundir com "não alterar".
const Object kUnset = Object();

/// Resolve um parâmetro de `copyWith` anulável.
T? escolher<T>(Object? valor, T? atual) =>
    identical(valor, kUnset) ? atual : valor as T?;
