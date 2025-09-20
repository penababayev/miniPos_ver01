import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ kIsWeb için eklendi

import '../../core/backup_service.dart';
import '../../data/local/isar_service.dart';

// Kaydetme yardımcıları (koşullu import)
import '../exports/csv_saver_io.dart'
    if (dart.library.html) '../exports/csv_saver_web.dart';
import '../exports/json_saver_io.dart'
    if (dart.library.html) '../exports/json_saver_web.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  bool _auto = false;
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final svc = BackupService.instance;
    final a = await svc.getAutoEnabled();
    final l = await svc.lastBackupAt();
    setState(() {
      _auto = a;
      _last = l;
    });
  }

  Isar get _isar => ref.read(isarProvider);

  Future<void> _exportJsonFull() async {
    setState(() => _busy = true);
    final bytes = await BackupService.instance.exportFullJsonBytes(_isar);
    final path = await saveJsonBytes(
        bytes, 'minipos_backup_${_ts(DateTime.now())}.json');
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('JSON yedek oluşturuldu: $path')));
  }

  Future<void> _importJsonFull() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (pick == null) return;
    final bytes = pick.files.single.bytes;
    if (bytes == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Geri Yükleme'),
        content: const Text(
            'Mevcut verileriniz SİLİNİP, seçtiğiniz yedek yüklenecek. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Evet')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final map = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    await BackupService.instance.importFullJson(_isar, map, replaceAll: true);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Yedek geri yüklendi.')));
  }

  Future<void> _exportCsvProducts() async {
    setState(() => _busy = true);
    final csv = await BackupService.instance.exportProductsCsv(_isar);
    final path = await saveCsvText(csv, 'products_${_ts(DateTime.now())}.csv');
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Ürün CSV: $path')));
  }

  Future<void> _exportCsvSales() async {
    setState(() => _busy = true);
    final csv = await BackupService.instance.exportSalesCsv(_isar);
    final path = await saveCsvText(csv, 'sales_${_ts(DateTime.now())}.csv');
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Satış CSV: $path')));
  }

  Future<void> _exportCsvItems() async {
    setState(() => _busy = true);
    final csv = await BackupService.instance.exportSaleItemsCsv(_isar);
    final path =
        await saveCsvText(csv, 'sale_items_${_ts(DateTime.now())}.csv');
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Kalem CSV: $path')));
  }

  Future<void> _toggleAuto(bool v) async {
    await BackupService.instance.setAutoEnabled(v);
    setState(() => _auto = v);
    if (v) {
      // İlk kurulumda hemen bir yedek al
      final path = await BackupService.instance
          .runDailyBackupIfNeeded(_isar, force: true);
      _last = DateTime.now();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Otomatik yedek aktif. ${path == 'web-cache' ? 'Tarayıcıda saklandı.' : 'Dosya oluşturuldu.'}')),
      );
      setState(() {});
    }
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    final path =
        await BackupService.instance.runDailyBackupIfNeeded(_isar, force: true);
    setState(() {
      _busy = false;
      _last = DateTime.now();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Yedek alındı. ${path == 'web-cache' ? 'Tarayıcıda saklandı (Yedeği indir ile alabilirsiniz).' : path}')),
    );
  }

  Future<void> _downloadWebLatest() async {
    final r = await BackupService.instance.downloadLastWebBackup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(r == null ? 'Önce otomatik yedek alın.' : 'İndirildi: $r')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yedekleme / Geri Yükleme')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SwitchListTile(
            value: _auto,
            onChanged: _busy ? null : _toggleAuto,
            title: const Text('Otomatik günlük JSON yedek'),
            subtitle: Text(
                _last == null ? 'Son yedek: -' : 'Son yedek: ${_fmt(_last!)}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('TAM JSON yedek (dışa aktar)'),
            subtitle: const Text('Ürünler, satışlar, kalemler, kullanıcılar'),
            trailing: FilledButton(
              onPressed: _busy ? null : _exportJsonFull,
              child: const Text('Dışa aktar'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('TAM JSON yedekten geri yükle'),
            subtitle: const Text('Mevcut veriler silinir ve yedek yüklenir'),
            trailing: OutlinedButton(
              onPressed: _busy ? null : _importJsonFull,
              child: const Text('İçe aktar'),
            ),
          ),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('Son otomatik web yedeğini indir'),
              trailing: OutlinedButton(
                onPressed: _busy ? null : _downloadWebLatest,
                child: const Text('Yedeği indir'),
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('Ürünler CSV'),
            trailing: OutlinedButton(
                onPressed: _busy ? null : _exportCsvProducts,
                child: const Text('Dışa aktar')),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Satışlar CSV'),
            trailing: OutlinedButton(
                onPressed: _busy ? null : _exportCsvSales,
                child: const Text('Dışa aktar')),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Satış kalemleri CSV'),
            trailing: OutlinedButton(
                onPressed: _busy ? null : _exportCsvItems,
                child: const Text('Dışa aktar')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : _backupNow,
              icon: const Icon(Icons.save),
              label: Text(_busy ? 'Çalışıyor...' : 'Hemen yedek al'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _ts(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}_${d.hour.toString().padLeft(2, '0')}-${d.minute.toString().padLeft(2, '0')}-${d.second.toString().padLeft(2, '0')}';
}
