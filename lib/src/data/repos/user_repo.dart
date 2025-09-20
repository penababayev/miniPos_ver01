import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../models/app_user.dart';
import '../../data/local/isar_service.dart';

class UserRepo {
  UserRepo(this.isar);
  final Isar isar;

  // --- PIN hash ---
  String _createSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    final h = sha256.convert(utf8.encode('$salt:$pin')).bytes;
    return base64Url.encode(h);
  }

  // Yeni kullanıcı
  Future<int> addUser({
    required String name,
    required UserRole role,
    required String pin,
    bool active = true,
  }) async {
    final u = AppUser()
      ..name = name
      ..role = role
      ..pinSalt = _createSalt()
      ..pinHash = '' // sonra set
      ..active = active
      ..createdAt = DateTime.now();

    u.pinHash = _hash(pin, u.pinSalt);

    return isar.writeTxn<int>(() async {
      return await isar.appUsers.put(u);
    });
  }

  Future<void> updatePin(int userId, String newPin) async {
    await isar.writeTxn(() async {
      final u = await isar.appUsers.get(userId);
      if (u == null) return;
      u.pinSalt = _createSalt();
      u.pinHash = _hash(newPin, u.pinSalt);
      await isar.appUsers.put(u);
    });
  }

  Future<List<AppUser>> allActive() async =>
      await isar.appUsers.filter().activeEqualTo(true).sortByName().findAll();

  Future<AppUser?> getById(int id) => isar.appUsers.get(id);

  Future<AppUser?> findByName(String name) async =>
      await isar.appUsers.filter().nameEqualTo(name).findFirst();

  Future<bool> verifyPin({required int userId, required String pin}) async {
    final u = await isar.appUsers.get(userId);
    if (u == null || !u.active) return false;
    final h = _hash(pin, u.pinSalt);
    return h == u.pinHash;
  }

  // İlk kurulumda örnek kullanıcılar
  Future<void> ensureSeed() async {
    final count = await isar.appUsers.count();
    if (count > 0) return;

    await addUser(
        name: 'Yönetici', role: UserRole.manager, pin: '1234'); // demo
    await addUser(name: 'Kasiyer', role: UserRole.cashier, pin: '0000'); // demo
  }
}
