import 'package:isar/isar.dart';

part 'app_user.g.dart';

@collection
class AppUser {
  Id id = Isar.autoIncrement;

  late String name;

  @enumerated
  late UserRole role; // cashier | manager

  // PIN doğrulama için (salt + sha256)
  late String pinSalt;
  late String pinHash;

  bool active = true;
  late DateTime createdAt;
}

enum UserRole { cashier, manager }
