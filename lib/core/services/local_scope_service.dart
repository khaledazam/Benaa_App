import 'dart:convert';

/// Local data belongs to an authenticated employee and one warehouse. Legacy
/// unscoped records are preserved in place, never imported into another scope.
class LocalScopeService {
  static String? actorId;
  static String? warehouseId;
  static String get key => actorId == null
      ? 'legacy'
      : base64Url.encode(utf8.encode('$actorId:${warehouseId ?? "unassigned"}'));
  static String preferenceKey(String name) => actorId == null ? name : '${key}_$name';
  static void select(String? actor, String? warehouse) {
    actorId = actor;
    warehouseId = warehouse;
  }
}
