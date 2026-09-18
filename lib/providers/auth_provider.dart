import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import '../core/services/pocketbase_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  static const _boxName = 'auth';
  static const _tokenKey = 'token';
  static const _userKey = 'user';

  final PocketBaseService _pb = PocketBaseService();

  Box? _box;
  User? _currentUser;
  bool _isLoggingIn = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoggingIn => _isLoggingIn;

  Future<void> init() async {
    try {
      _box ??= await Hive.openBox<dynamic>(_boxName);
      final token = _box!.get(_tokenKey) as String?;
      final userJson = _box!.get(_userKey);
      if (token != null && token.isNotEmpty && userJson is Map) {
        final recordJson = Map<String, dynamic>.from(userJson);
        _currentUser = User.fromJson(recordJson);
        _pb.restoreAuth(token, recordJson);
      }
    } catch (_) {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<User> login({required String email, required String password}) async {
    _isLoggingIn = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _pb.login(email: email, password: password);
      _currentUser = user;
      final token = _pb.authToken;

      if (token != null) {
        await _box?.put(_tokenKey, token);
        await _box?.put(_userKey, {
          'id': user.id,
          'email': user.email,
          if (user.name != null) 'name': user.name,
          'type': user.type.value,
        });
      }

      notifyListeners();
      return user;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _pb.requestPasswordReset(email);
  }

  String? _error;
  String? get errorMessage {
    final e = _error;
    if (e == null) return null;
    final message = e.toString();
    if (message.contains('invalid') || message.contains('401')) {
      return 'Invalid email or password';
    }
    return 'Unable to sign in. Please try again.';
  }

  Future<void> logout() async {
    _pb.logout();
    _currentUser = null;
    _error = null;
    await _box?.delete(_tokenKey);
    await _box?.delete(_userKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _box = null;
    super.dispose();
  }
}
