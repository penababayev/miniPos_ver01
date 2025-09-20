import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tema & Lisans
import 'core/theme.dart';
import 'core/license_service.dart';

// Yetki & Kimlik
import 'core/role_gate.dart';
import 'core/auth_controller.dart';
import 'models/app_user.dart';

// Isar (auto-backup için lazım)
import 'data/local/isar_service.dart';

// Ekranlar
import 'features/products/products_list_page.dart';
import 'features/pos/pos_page.dart';
import 'features/reports/reports_page.dart';
import 'features/license/license_key_page.dart';
import 'features/auth/login_page.dart';
import 'features/users/user_management_page.dart';
import 'features/settings/backup_page.dart';

// Diyaloglar
import 'features/auth/change_pin_dialog.dart';

// Backup servisi
import 'core/backup_service.dart';

class MiniPOSApp extends ConsumerWidget {
  const MiniPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lisans servisini başlat (banner vb. için)
    LicenseService().init();

    return MaterialApp(
      title: 'MiniPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routes: {
        '/license': (_) => const LicenseKeyPage(),
        '/login': (_) => const LoginPage(),
        '/users': (_) => const UserManagementPage(),
        '/backup': (_) => const BackupPage(), // ✅ Yedekleme sayfası
      },
      home: const _Home(),
    );
  }
}

class _Home extends ConsumerStatefulWidget {
  const _Home();
  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    // Uygulama açılışında otomatik günlük yedek (gerekliyse) sessizce çalıştır.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isar = ref.read(isarProvider);
      await BackupService.instance.runDailyBackupIfNeeded(isar);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final u = auth.user;

    // Raporlar sekmesini RoleGate ile yalnızca YÖNETİCİye aç
    final pages = <Widget>[
      const ProductsListPage(),
      const POSPage(),
      const RoleGate(minRole: UserRole.manager, child: ReportsPage()),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('MiniPOS'),
        actions: [
          // Kullanıcı çipi (giriş/menü)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.person),
              label: Text(
                u == null
                    ? 'Giriş Yap'
                    : '${u.name} • ${u.role == UserRole.manager ? 'Yönetici' : 'Kasiyer'}',
              ),
              onPressed: () {
                if (u == null) {
                  Navigator.pushNamed(context, '/login');
                } else {
                  _openUserMenu(context);
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Abonelik / Anahtar',
            onPressed: () => Navigator.pushNamed(context, '/license'),
            icon: const Icon(Icons.vpn_key),
          ),
        ],
      ),
      body: IndexedStack(index: idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Ürünler'),
          NavigationDestination(
              icon: Icon(Icons.point_of_sale), label: 'Satış'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Raporlar'),
        ],
      ),
    );
  }

  void _openUserMenu(BuildContext context) {
    final auth = ref.read(authControllerProvider);
    final authN = ref.read(authControllerProvider.notifier);
    final me = auth.user;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            // ✅ Yedekleme / Geri Yükleme (herkese açık; istersen yöneticiyi şart koşabilirsin)
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Yedekleme / Geri Yükleme'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/backup');
              },
            ),
            if (me?.role == UserRole.manager) // ✅ Yalnızca yönetici
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Kullanıcı Yönetimi'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/users');
                },
              ),
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: const Text('Kullanıcı Değiştir'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
            ),
            if (me != null)
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('PIN’imi Değiştir'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => ChangePinDialog(
                      targetUser: me,
                      requireOldPin:
                          true, // kendi PIN’ini değiştirirken mevcut PIN istenir
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () {
                authN.logout();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
