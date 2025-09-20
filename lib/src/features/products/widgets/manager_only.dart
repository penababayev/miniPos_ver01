import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth_controller.dart';
import '../../../models/app_user.dart';

/// Yalnızca Yönetici ise child'ı gösterir; değilse hiç göstermez.
class ManagerOnly extends ConsumerWidget {
  const ManagerOnly({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authControllerProvider).user?.role ?? UserRole.cashier;
    final isManager = role == UserRole.manager;
    return isManager ? child : const SizedBox.shrink();
  }
}
