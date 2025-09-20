import 'package:flutter/material.dart';
import 'license_service.dart';

/// Lisans pasifse sayfanın üstünde uyarı bandı gösterir.
/// Reaktif çalışır: Lisans aktif olduğunda otomatik gizlenir.
class LicenseBanner extends StatelessWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = LicenseService();
    // Realtime dinle
    return ValueListenableBuilder<bool>(
      valueListenable: svc.active,
      builder: (_, isActive, __) {
        if (isActive) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                    'Abonelik pasif. Bazı işlemler kısıtlandı. Anahtar girerek aktif edin.'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed('/license'),
                child: const Text('Anahtar Gir'),
              ),
            ],
          ),
        );
      },
    );
  }
}
