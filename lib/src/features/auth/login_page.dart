import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../models/app_user.dart';
import 'admin_recovery_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  AppUser? selected;
  final pinCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Girişi')),
      body: FutureBuilder(
        future: ref.read(authControllerProvider.notifier).listUsers(),
        builder: (_, snap) {
          final users = snap.data ?? <AppUser>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Kullanıcı seçin:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: users.map((u) {
                  final sel = selected?.id == u.id;
                  return ChoiceChip(
                    label: Text(
                        '${u.name} ${u.role == UserRole.manager ? '(Yönetici)' : ''}'),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      selected = u;
                      error = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('PIN girin:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(
                  hintText: '****',
                  prefixIcon: Icon(Icons.password),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                onChanged: (_) => setState(() => error = null),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: auth.loading ? null : _doLogin,
                icon: const Icon(Icons.login),
                label: const Text('Giriş'),
              ),
              const SizedBox(height: 8),
              // 🔑 Yönetici PIN kurtarma
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AdminRecoveryDialog(),
                  );
                },
                icon: const Icon(Icons.vpn_key),
                label: const Text('Yönetici PIN’ini unuttum'),
              ),
              const SizedBox(height: 12),
              const Text('Demo PIN: Yönetici=1234, Kasiyer=0000',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _doLogin() async {
    if (selected == null) {
      setState(() => error = 'Önce kullanıcı seçin.');
      return;
    }
    if (pinCtrl.text.trim().isEmpty) {
      setState(() => error = 'PIN girin.');
      return;
    }
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(userId: selected!.id, pin: pinCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context); // geri dön
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hoş geldiniz, ${selected!.name}')),
      );
    } else {
      setState(() => error = 'PIN hatalı.');
    }
  }
}
