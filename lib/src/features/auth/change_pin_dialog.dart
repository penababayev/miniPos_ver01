import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../data/repos/user_repo.dart';
import '../../data/local/isar_service.dart';
import '../../models/app_user.dart';

class ChangePinDialog extends ConsumerStatefulWidget {
  const ChangePinDialog({
    super.key,
    required this.targetUser, // PIN’i değiştirilecek kullanıcı
    this.requireOldPin = true, // true: kendi PIN’imi değiştiriyorum
  });

  final AppUser targetUser;
  final bool requireOldPin;

  @override
  ConsumerState<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<ChangePinDialog> {
  final _form = GlobalKey<FormState>();
  final oldPinCtrl = TextEditingController();
  final adminPinCtrl =
      TextEditingController(); // yönetici resetlerken onun PIN’i
  final newPinCtrl = TextEditingController();
  final newPin2Ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    oldPinCtrl.dispose();
    adminPinCtrl.dispose();
    newPinCtrl.dispose();
    newPin2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final isar = ref.read(isarProvider);
    final users = UserRepo(isar);
    final auth = ref.read(authControllerProvider);
    final me = auth.user;

    // 1) Doğrulama
    bool ok = false;
    if (widget.requireOldPin) {
      ok = await users.verifyPin(
          userId: widget.targetUser.id, pin: oldPinCtrl.text.trim());
      if (!ok) {
        setState(() {
          _loading = false;
          _error = 'Mevcut PIN yanlış.';
        });
        return;
      }
    } else {
      // Yalnızca yönetici başka birinin PIN’ini sıfırlayabilir
      if (me == null || me.role != UserRole.manager) {
        setState(() {
          _loading = false;
          _error = 'Yalnızca yönetici sıfırlayabilir.';
        });
        return;
      }
      final okAdmin =
          await users.verifyPin(userId: me.id, pin: adminPinCtrl.text.trim());
      if (!okAdmin) {
        setState(() {
          _loading = false;
          _error = 'Yönetici PIN’i yanlış.';
        });
        return;
      }
    }

    // 2) Yeni PIN eşleşmesi
    final p1 = newPinCtrl.text.trim();
    final p2 = newPin2Ctrl.text.trim();
    if (p1 != p2) {
      setState(() {
        _loading = false;
        _error = 'Yeni PIN’ler uyuşmuyor.';
      });
      return;
    }

    // 3) Güncelle
    await users.updatePin(widget.targetUser.id, p1);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PIN güncellendi: ${widget.targetUser.name}')),
    );
  }

  String? _pinValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Zorunlu';
    if (s.length < 4 || s.length > 8) return '4–8 haneli olmalı';
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'Sadece rakam kullanılmalı';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.targetUser;
    return AlertDialog(
      title: Text(widget.requireOldPin
          ? 'PIN Değiştir — ${t.name}'
          : 'PIN Sıfırla — ${t.name}'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.requireOldPin) ...[
                TextFormField(
                  controller: oldPinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mevcut PIN',
                    prefixIcon: Icon(Icons.password),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: _pinValidator,
                ),
                const SizedBox(height: 8),
              ] else ...[
                TextFormField(
                  controller: adminPinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Yönetici PIN’i',
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: _pinValidator,
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: newPinCtrl,
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
                controller: newPin2Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Yeni PIN (tekrar)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: _pinValidator,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('İptal')),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.save),
          label: Text(_loading ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}
