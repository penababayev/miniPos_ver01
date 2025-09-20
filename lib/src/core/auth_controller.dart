import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../data/local/isar_service.dart';
import '../data/repos/user_repo.dart';
import '../models/app_user.dart';

class AuthState {
  final AppUser? user;
  final bool loading;
  const AuthState({this.user, this.loading = false});
  AuthState copyWith({AppUser? user, bool? loading}) =>
      AuthState(user: user ?? this.user, loading: loading ?? this.loading);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState(loading: true)) {
    _init();
  }

  final Ref _ref;
  UserRepo get _users => UserRepo(_ref.read(isarProvider));

  Future<void> _init() async {
    final isar = _ref.read(isarProvider);
    // seed demo users
    await _users.ensureSeed();

    // Otomatik giriş yok → login ekranı
    state = const AuthState(user: null, loading: false);
  }

  Future<List<AppUser>> listUsers() => _users.allActive();

  Future<bool> login({required int userId, required String pin}) async {
    state = state.copyWith(loading: true);
    final ok = await _users.verifyPin(userId: userId, pin: pin);
    if (ok) {
      final u = await _users.getById(userId);
      state = AuthState(user: u, loading: false);
    } else {
      state = state.copyWith(loading: false);
    }
    return ok;
  }

  void logout() => state = const AuthState(user: null, loading: false);

  bool hasRole(UserRole min) {
    final u = state.user;
    if (u == null) return false;
    // cashier < manager
    if (min == UserRole.cashier) return true;
    return u.role == UserRole.manager;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
