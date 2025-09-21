import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/license_service.dart';
import 'admin_recovery_dialog.dart';

class LoginGatePage extends ConsumerWidget {
  const LoginGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0ea5e9), Color(0xFF9333ea)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront, size: 56),
                    const SizedBox(height: 8),
                    const Text('MiniPOS',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    FutureBuilder(
                      future: LicenseService().current(),
                      builder: (_, snap) {
                        final active = snap.data?.isActive ?? false;
                        return Chip(
                          avatar: Icon(
                              active
                                  ? Icons.verified
                                  : Icons.warning_amber_rounded,
                              color: active ? Colors.green : Colors.orange,
                              size: 18),
                          label: Text(
                              active ? 'Abonelik aktif' : 'Abonelik pasif'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Devam etmek için giriş yapın.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('Giriş Yap'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/license'),
                            icon: const Icon(Icons.vpn_key),
                            label: const Text('Lisans Anahtarı'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const AdminRecoveryDialog(),
                              );
                            },
                            icon: const Icon(Icons.key),
                            label: const Text('PIN Kurtarma'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Güvenlik için giriş yapmadan veriler gösterilmez.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
