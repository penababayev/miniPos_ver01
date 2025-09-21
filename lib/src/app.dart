import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tema & Lisans
import 'core/theme.dart';
import 'core/license_service.dart';

// Yetki & Kimlik
import 'core/role_gate.dart';
import 'core/auth_controller.dart';
import 'models/app_user.dart';

// Isar (auto-backup için)
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

// Login Gate ekranı
import 'features/auth/login_gate_page.dart';

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
        '/backup': (_) => const BackupPage(),
      },
      home: const _RootGate(),
    );
  }
}

/// Açılışta servisleri hazırlar ve kimliğe göre ekrana karar verir.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Servisler
    await IsarService.instance.init();
    await LicenseService().init();

    // Sessiz otomatik günlük yedek
    final isar = IsarService.instance.db;
    await BackupService.instance.runDailyBackupIfNeeded(isar);

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _Splash();
    }

    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    // Kullanıcı yoksa: Login Gate
    if (user == null) {
      return const LoginGatePage();
    }

    // Kullanıcı varsa: Ana kabuk
    return const _MainShell();
  }
}

/// Açılış Splash
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.storefront, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text('MiniPOS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 18),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana uygulama kabuğu (giriş sonrası)
class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final u = auth.user;

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
          // Kullanıcı çipi (menü)
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
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Yedekleme / Geri Yükleme'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/backup');
              },
            ),
            if (me?.role == UserRole.manager)
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
                      requireOldPin: true,
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
