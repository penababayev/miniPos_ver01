import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/role_gate.dart';
import '../../models/app_user.dart';
import '../../core/auth_controller.dart';
import '../../data/local/isar_service.dart';
import '../../data/repos/user_repo.dart';
import '../auth/change_pin_dialog.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});
  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  bool _loading = true;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final isar = ref.read(isarProvider);
    final repo = UserRepo(isar);
    final list = await repo.allActive();
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _addUser() async {
    final nameCtl = TextEditingController();
    String role = 'cashier';
    final pinCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Kullanıcı'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'İsim',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(value: 'cashier', child: Text('Kasiyer')),
                  DropdownMenuItem(value: 'manager', child: Text('Yönetici')),
                ],
                onChanged: (v) => role = v ?? 'cashier',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtl,
                decoration: const InputDecoration(
                  labelText: 'PIN (4–8 rakam)',
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (nameCtl.text.trim().isEmpty || pinCtl.text.trim().length < 4)
                return;
              final isar = ref.read(isarProvider);
              final repo = UserRepo(isar);
              await repo.addUser(
                name: nameCtl.text.trim(),
                role: role == 'manager' ? UserRole.manager : UserRole.cashier,
                pin: pinCtl.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı eklendi')));
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sayfayı sadece yönetici görebilsin
    return RoleGate(
      minRole: UserRole.manager,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? const Center(child: Text('Kayıtlı kullanıcı yok'))
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      return ListTile(
                        leading: CircleAvatar(
                            child: Text(u.name.characters.first.toUpperCase())),
                        title: Text(u.name),
                        subtitle: Text(u.role == UserRole.manager
                            ? 'Yönetici'
                            : 'Kasiyer'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ChangePinDialog(
                                    targetUser: u,
                                    requireOldPin:
                                        false, // yönetici başka birinin PIN’ini sıfırlar
                                  ),
                                ).then((_) => _load());
                              },
                              icon: const Icon(Icons.lock_reset),
                              label: const Text('PIN Sıfırla'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addUser,
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
