import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import 'auth_controller.dart';

/// Bir sayfayı/alanı minimum role göre korur.
/// Örn: RoleGate(minRole: UserRole.manager, child: ReportsPage())
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key, required this.minRole, required this.child});
  final UserRole minRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.user == null) {
      // Giriş yapılmamış
      return _Blocked(
        title: 'Giriş Gerekli',
        message: 'Bu bölümü görmek için giriş yapın.',
        actionText: 'Giriş',
        action: () => Navigator.pushNamed(context, '/login'),
      );
    }
    // cashier < manager
    final u = auth.user!;
    final ok = minRole == UserRole.cashier || u.role == UserRole.manager;
    if (!ok) {
      return const _Blocked(
        title: 'Yetki Yetersiz',
        message: 'Bu bölüm yalnızca yönetici için erişilebilir.',
      );
    }
    return child;
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked(
      {required this.title,
      required this.message,
      this.action,
      this.actionText});
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 36),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: action, child: Text(actionText ?? 'Tamam')),
              ]
            ]),
          ),
        ),
      ),
    );
  }
}
