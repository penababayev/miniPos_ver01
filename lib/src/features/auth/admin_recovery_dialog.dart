import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/license_service.dart';
import '../../data/local/isar_service.dart';
import '../../data/repos/user_repo.dart';
import '../../models/app_user.dart';

class AdminRecoveryDialog extends ConsumerStatefulWidget {
  const AdminRecoveryDialog({super.key});

  @override
  ConsumerState<AdminRecoveryDialog> createState() =>
      _AdminRecoveryDialogState();
}

class _AdminRecoveryDialogState extends ConsumerState<AdminRecoveryDialog> {
  final _form = GlobalKey<FormState>();
  final _keyCtrl = TextEditingController();
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();

  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  String? _pinValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Zorunlu';
    if (s.length < 4 || s.length > 8) return '4–8 haneli olmalı';
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'Sadece rakam';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_pin1.text.trim() != _pin2.text.trim()) {
      setState(() => _err = 'Yeni PIN’ler uyuşmuyor.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });

    final lic = LicenseService();
    final okKey = await lic.keyMatches(_keyCtrl.text.trim());
    final info = await lic.current();

    if (!okKey || !info.isActive) {
      setState(() {
        _busy = false;
        _err = 'Lisans anahtarı hatalı veya abonelik pasif.';
      });
      return;
    }

    final isar = ref.read(isarProvider);
    final users = UserRepo(isar);

    // findFirst() yerine findAll() + first
    final mgrList =
        await isar.appUsers.filter().roleEqualTo(UserRole.manager).findAll();

    AppUser? mngr = mgrList.isNotEmpty ? mgrList.first : null;

    if (mngr == null) {
      // Hiç yönetici yoksa yeni oluştur
      await users.addUser(
        name: 'Yönetici',
        role: UserRole.manager,
        pin: _pin1.text.trim(),
      );
    } else {
      // Var olan yöneticinin PIN’ini güncelle
      await users.updatePin(mngr.id, _pin1.text.trim());
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yönetici PIN’i sıfırlandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yönetici PIN Kurtarma'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Geçerli lisans anahtarını girin ve yeni yönetici PIN’i belirleyin.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lisans anahtarı',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pin1,
                decoration: const InputDecoration(
                  labelText: 'Yeni PIN',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: _pinValidator,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pin2,
                decoration: const InputDecoration(
                  labelText: 'Yeni PIN (tekrar)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: _pinValidator,
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('İptal')),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.check),
          label: Text(_busy ? 'İşleniyor...' : 'Onayla'),
        ),
      ],
    );
  }
}
