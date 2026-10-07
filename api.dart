import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  String? token;

  Future<void> loadToken() async =>
      token = (await SharedPreferences.getInstance()).getString('token');

  Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t == null ? await p.remove('token') : await p.setString('token', t);
  }

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 400) {
      throw ApiException(
          body is Map ? '${body['error'] ?? 'Something went wrong'}' : 'Error ${r.statusCode}');
    }
    return body;
  }

  Uri _u(String p) => Uri.parse('$apiBase$p');

  Future<dynamic> get(String p) async {
    try {
      return _handle(await http.get(_u(p), headers: _h));
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Check your connection.');
    }
  }

  Future<dynamic> post(String p, Map body) async {
    try {
      return _handle(await http.post(_u(p), headers: _h, body: jsonEncode(body)));
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Check your connection.');
    }
  }

  Future<dynamic> patch(String p, Map body) async =>
      _handle(await http.patch(_u(p), headers: _h, body: jsonEncode(body)));

  Future<dynamic> delete(String p) async =>
      _handle(await http.delete(_u(p), headers: _h));
}
