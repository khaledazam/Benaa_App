import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_auth_service.dart';
import 'local_scope_service.dart';
import 'mongodb_sync_service.dart';
import 'benaa_warehouse_service.dart';
import 'package:uuid/uuid.dart';

class ProjectService {
  static Uri uri(String path) => Uri.parse(MongoDbSyncService.apiBase).resolve(path);
  static Future<List<Map<String, dynamic>>> list(String path, String field) async {
    final scope = LocalScopeService.key;
    final response = await http.get(uri(path), headers: await CloudAuthService.authenticatedHeaders())
      .timeout(const Duration(seconds: 10));
    if (scope != LocalScopeService.key) throw StateError('Account or warehouse changed');
    if (response.statusCode != 200) throw StateError('Server rejected request (${response.statusCode})');
    final body = jsonDecode(response.body);
    final result = (body[field] as List).map((entry) => Map<String, dynamic>.from(entry)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalScopeService.preferenceKey('project_cache_$field'), jsonEncode(result));
    return result;
  }
  static Future<List<Map<String, dynamic>>> cached(String field) async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(LocalScopeService.preferenceKey('project_cache_$field')) ?? '[]') as List)
      .map((entry) => Map<String, dynamic>.from(entry)).toList();
  }
  static Future<void> createProject(Map<String, dynamic> project) async {
    final response = await http.post(uri('/api/projects'),
      headers: await CloudAuthService.authenticatedHeaders(),
      body: jsonEncode({...project, 'idempotencyKey': const Uuid().v4()}))
      .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Project not created (${response.statusCode})');
    }
  }
  static Future<Map<String, dynamic>> issue(Map<String, dynamic> payload) =>
    BenaaWarehouseService.submitOperation(payload, operationType: 'MATERIAL_ISSUE_LIFECYCLE');
}
