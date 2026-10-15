import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Android emulator -> your laptop. For a real phone, use your laptop's
// Wi-Fi IP instead, e.g. 'http://192.168.1.5:8000'.
const String baseUrl = 'http://10.0.2.2:8000';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class Api {
  static String? _token;
  static String? adminUsername;

  static bool get isLoggedIn => _token != null;

  static Future<void> loadSession() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    adminUsername = p.getString('admin_username');
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('admin_username');
    _token = null;
    adminUsername = null;
  }

  static Future<String> _loginRequest(String username, String password) async {
    final res = await _send('POST', '/auth/login',
        body: {'username': username, 'password': password}, auth: false);
    return res['access_token'] as String;
  }

  static Future<void> login(String username, String password) async {
    final token = await _loginRequest(username, password);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
    await p.setString('admin_username', username);
    _token = token;
    adminUsername = username;
  }

  /// Re-checks the admin password without changing the saved session.
  static Future<bool> verifyAdminPassword(String password) async {
    try {
      await _loginRequest(adminUsername ?? '', password);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return false;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> checkIn(String username) async {
    final res = await _send('POST', '/checkin', body: {'username': username});
    return res as Map<String, dynamic>;
  }

  // ----- used by the admin dashboard (next step) -----

  static Future<List<dynamic>> getMembers(
      {String search = '', String status = ''}) async {
    final q = Uri(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
    }).query;
    final res = await _send('GET', '/members${q.isEmpty ? '' : '?$q'}');
    return res as List<dynamic>;
  }

  static Future<void> createMember(Map<String, dynamic> member) async {
    await _send('POST', '/members', body: member);
  }

  static Future<void> updateMember(int id, Map<String, dynamic> member) async {
    await _send('PUT', '/members/$id', body: member);
  }

  static Future<void> deleteMember(int id) async {
    await _send('DELETE', '/members/$id');
  }

  static Future<Map<String, dynamic>> setMembership(
      int memberId, String type) async {
    final res = await _send('POST', '/members/$memberId/membership',
        body: {'membership_type': type});
    return res as Map<String, dynamic>;
  }

  static Future<void> editMembership(
      int membershipId, String expirationDate) async {
    await _send('PATCH', '/memberships/$membershipId',
        body: {'expiration_date': expirationDate});
  }

  static Future<List<dynamic>> getAttendance(
      {String? day, int? memberId}) async {
    final q = Uri(queryParameters: {
      if (day != null) 'day': day,
      if (memberId != null) 'member_id': '$memberId',
    }).query;
    final res = await _send('GET', '/attendance${q.isEmpty ? '' : '?$q'}');
    return res as List<dynamic>;
  }

  static Future<int> sendReminders() async {
    final res = await _send('POST', '/admin/send-reminders');
    return res['sent'] as int;
  }

  // ----- shared request helper -----

  static Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (auth && _token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    if (body != null) request.body = jsonEncode(body);

    http.Response res;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 10));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(0, 'Cannot reach the server. Is the backend running?');
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    String message = 'Something went wrong (${res.statusCode}).';
    if (data is Map && data['detail'] is String) {
      message = data['detail'] as String;
    } else if (res.statusCode == 422) {
      message = 'Please check the information you entered.';
    }
    throw ApiException(res.statusCode, message);
  }
}