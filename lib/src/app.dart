import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/products/products_list_page.dart';
import 'features/pos/pos_page.dart';
import 'features/reports/reports_page.dart';

class MiniPOSApp extends ConsumerWidget {
  const MiniPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'MiniPOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int idx = 0;
  final pages = const [ProductsListPage(), POSPage(), ReportsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiniPOS MVP')),
      body: pages[idx],
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
}
