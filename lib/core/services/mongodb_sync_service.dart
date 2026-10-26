import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/item_model.dart';

/// Central MongoDB Atlas Database & Synchronization Service for Benaa Mobile
class MongoDbSyncService {
  // Database credentials belong exclusively on the backend.
  static const String databaseName = 'server-managed';
  static const String clusterHost = 'server-managed';
  static const String databaseUser = 'server-managed';

  static const String _spApiEndpointKey = 'benaa_mongodb_api_endpoint';
  static const String _spLastSyncKey = 'benaa_last_mongodb_sync_time';

  static String _apiBase = 'http://localhost:3000/api/mobile-sync';

  static String get apiBase => _apiBase;
  static String get maskedConnectionUrl => 'Managed securely by the backend';

  /// Initialize and load saved API endpoint if custom
  static Future<void> initialize() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final savedEndpoint = sp.getString(_spApiEndpointKey);
      if (savedEndpoint != null && savedEndpoint.isNotEmpty) {
        _apiBase = savedEndpoint;
      }
    } catch (e) {
      debugPrint("MongoDbSyncService initialization error: $e");
    }
  }

  /// Update API bridge endpoint
  static Future<void> setApiEndpoint(String newEndpoint) async {
    _apiBase = newEndpoint.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_spApiEndpointKey, _apiBase);
  }

  /// Get formatted last sync timestamp
  static Future<String> getLastSyncTime() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_spLastSyncKey) ?? 'لم تتم المزامنة بعد';
    } catch (_) {
      return 'لم تتم المزامنة بعد';
    }
  }

  /// Ping MongoDB Atlas connection via sync gateway
  static Future<Map<String, dynamic>> checkConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse(_apiBase), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'connected': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'database': data['database'] ?? databaseName,
          'cluster': data['cluster'] ?? clusterHost,
          'user': data['user'] ?? databaseUser,
          'stats': data['stats'] ?? {},
          'message': 'متصل بنجاح مع قاعدة بيانات MongoDB المركزية',
        };
      } else {
        return {
          'connected': false,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'error': 'Server responded with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'connected': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
      };
    }
  }

  /// Push local items to MongoDB Atlas Product collection
  static Future<Map<String, dynamic>> syncLocalItemsToMongo(List<ItemModel> items) async {
    try {
      final payload = {
        'action': 'sync_items',
        'items': items.map((i) => {
          'code': i.code,
          'name': i.name,
          'category': i.category,
          'currentStock': i.currentStock,
          'unitPrice': i.unitPrice,
          'unit': i.unit,
          'location': i.location,
        }).toList(),
      };

      final response = await http
          .post(
            Uri.parse(_apiBase),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sp = await SharedPreferences.getInstance();
        final nowStr = DateTime.now().toString().split('.').first;
        await sp.setString(_spLastSyncKey, nowStr);

        return {
          'success': true,
          'count': data['upsertedCount'] ?? items.length,
          'message': data['message'] ?? 'تمت مزامنة الأصناف بنجاح مع MongoDB',
          'time': nowStr,
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Pull products from MongoDB Atlas to local app
  static Future<List<Map<String, dynamic>>> pullProductsFromMongo() async {
    try {
      final payload = {'action': 'pull_items'};
      final response = await http
          .post(
            Uri.parse(_apiBase),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['items'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint("Error pulling products from MongoDB: $e");
    }
    return [];
  }

  /// Register / Provision a User directly into MongoDB Atlas User collection
  static Future<bool> registerUserInMongo({
    required String name,
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      final payload = {
        'action': 'sync_user',
        'user': {
          'name': name,
          'email': email,
          'username': username,
          'password': password,
          'role': role,
        },
      };

      final response = await http
          .post(
            Uri.parse(_apiBase),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint("Error registering user in MongoDB: $e");
    }
    return false;
  }
}
