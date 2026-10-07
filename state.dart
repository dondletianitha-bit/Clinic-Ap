import 'package:flutter/foundation.dart';
import 'api.dart';

class AuthState extends ChangeNotifier {
  final Api api = Api();
  Map<String, dynamic>? user;
  bool loading = true;

  bool get isAdmin => user?['role'] == 'admin';

  Future<void> init() async {
    await api.loadToken();
    if (api.token != null) {
      try {
        user = Map<String, dynamic>.from(await api.get('/api/me'));
      } catch (_) {
        await api.setToken(null);
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _finish(dynamic res) async {
    await api.setToken(res['token']);
    user = Map<String, dynamic>.from(res['user']);
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _finish(await api.post('/api/auth/login', {'email': email, 'password': password}));

  Future<void> register(String name, String email, String phone, String password) async =>
      _finish(await api.post('/api/auth/register',
          {'name': name, 'email': email, 'phone': phone, 'password': password}));

  Future<void> logout() async {
    await api.setToken(null);
    user = null;
    notifyListeners();
  }
}
