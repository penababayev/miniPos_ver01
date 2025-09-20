import 'package:flutter/material.dart';
import '../../data/local/debt_ledger_store.dart';
// CSV kaydetme (web/io otomatik seçer)
import '../reports/csv_saver_io.dart'
    if (dart.library.html) '../reports/csv_saver_web.dart';

enum LedgerStatus { all, open, settled, overdue }

enum LedgerSort {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  dueAsc,
  dueDesc,
  nameAsc,
  nameDesc
}

class DebtLedgerPage extends StatefulWidget {
  const DebtLedgerPage({super.key});
  @override
  State<DebtLedgerPage> createState() => _DebtLedgerPageState();
}

class _DebtLedgerPageState extends State<DebtLedgerPage> {
  final store = DebtLedgerStore();

  // filtreler
  final TextEditingController _q = TextEditingController();
  final TextEditingController _minCtl = TextEditingController();
  final TextEditingController _maxCtl = TextEditingController();
  LedgerStatus status = LedgerStatus.open;
  LedgerSort sort = LedgerSort.dateDesc;
  DateTimeRange? range;

  Future<List<DebtEntry>>? _f;

  @override
  void initState() {
    super.initState();
    _f = store.list();
  }

  @override
  void dispose() {
    _q.dispose();
    _minCtl.dispose();
    _maxCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _f = store.list());
  }

  List<DebtEntry> _applyFilters(List<DebtEntry> src) {
    var list = List<DebtEntry>.from(src);

    // Arama
    final q = _q.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final t = (e.customerName + ' ' + (e.phone ?? '')).toLowerCase();
        return t.contains(q);
      }).toList();
    }

    // Durum
    list = list.where((e) {
      switch (status) {
        case LedgerStatus.all:
          return true;
        case LedgerStatus.open:
          return !e.settled;
        case LedgerStatus.settled:
          return e.settled;
        case LedgerStatus.overdue:
          return e.isOverdue;
      }
    }).toList();

    // Tarih aralığı (createdAt)
    if (range != null) {
      final s =
          DateTime(range!.start.year, range!.start.month, range!.start.day);
      final e = DateTime(range!.end.year, range!.end.month, range!.end.day)
          .add(const Duration(days: 1));
      list = list
          .where((x) =>
              x.createdAt
                  .isAfter(s.subtract(const Duration(milliseconds: 1))) &&
              x.createdAt.isBefore(e))
          .toList();
    }

    // Tutar aralığı
    final minV = double.tryParse(_minCtl.text.replaceAll(',', '.'));
    final maxV = double.tryParse(_maxCtl.text.replaceAll(',', '.'));
    if (minV != null) list = list.where((e) => (e.amount) >= minV).toList();
    if (maxV != null) list = list.where((e) => (e.amount) <= maxV).toList();

    // Sıralama
    int cmpNum(num a, num b) => a.compareTo(b);
    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    list.sort((a, b) {
      switch (sort) {
        case LedgerSort.dateDesc:
          return b.createdAt.compareTo(a.createdAt);
        case LedgerSort.dateAsc:
          return a.createdAt.compareTo(b.createdAt);
        case LedgerSort.amountDesc:
          return cmpNum(b.amount, a.amount);
        case LedgerSort.amountAsc:
          return cmpNum(a.amount, b.amount);
        case LedgerSort.dueAsc:
          return (a.dueDate ?? DateTime(3000))
              .compareTo(b.dueDate ?? DateTime(3000));
        case LedgerSort.dueDesc:
          return (b.dueDate ?? DateTime(0)).compareTo(a.dueDate ?? DateTime(0));
        case LedgerSort.nameAsc:
          return cmpStr(a.customerName, b.customerName);
        case LedgerSort.nameDesc:
          return cmpStr(b.customerName, a.customerName);
      }
    });

    return list;
  }

  Future<void> _exportCsv(List<DebtEntry> list) async {
    final sb = StringBuffer()
      ..writeln(
          'Müşteri;Telefon;Not;Tutar;Tahsil;Kalan;Durum;Vade;Tarih;SatışID');
    for (final e in list) {
      sb.writeln([
        _csvSafe(e.customerName),
        _csvSafe(e.phone ?? '-'),
        _csvSafe(e.note ?? ''),
        e.amount.toStringAsFixed(2),
        e.paid.toStringAsFixed(2),
        e.remaining.toStringAsFixed(2),
        e.settled ? 'Kapalı' : (e.isOverdue ? 'Vadesi Geçmiş' : 'Açık'),
        e.dueDate?.toIso8601String() ?? '-',
        e.createdAt.toIso8601String(),
        e.saleId.toString(),
      ].join(';'));
    }
    await saveCsv(sb.toString(), 'borc_defteri.csv');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CSV indirildi.')));
    }
  }

  String _csvSafe(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _addPayment(DebtEntry e) async {
    final ctl = TextEditingController(text: e.remaining.toStringAsFixed(2));
    final v = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Tahsilat — ${e.customerName}'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              prefixText: '₺ ', labelText: 'Tahsil edilecek tutar'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final x = double.tryParse(ctl.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(context, x);
            },
            child: const Text('Ekle'),
          )
        ],
      ),
    );
    if (v == null) return;
    await store.addPayment(e.id, v);
    if (mounted) _refresh();
  }

  Future<void> _setDue(DebtEntry e) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: e.dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null) return;
    await store.setDueDate(e.id, picked);
    if (mounted) _refresh();
  }

  Future<void> _edit(DebtEntry e) async {
    final name = TextEditingController(text: e.customerName);
    final phone = TextEditingController(text: e.phone ?? '');
    final note = TextEditingController(text: e.note ?? '');
    final amount = TextEditingController(text: e.amount.toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borç Kaydını Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Müşteri adı')),
            const SizedBox(height: 8),
            TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Telefon')),
            const SizedBox(height: 8),
            TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Not')),
            const SizedBox(height: 8),
            TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Toplam borç (₺)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;

    await store.updateDetails(
      e.id,
      customerName:
          name.text.trim().isEmpty ? e.customerName : name.text.trim(),
      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      amount: double.tryParse(amount.text.replaceAll(',', '.')),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borç Defteri'),
        actions: [
          IconButton(
            tooltip: 'Filtreleri temizle',
            onPressed: () => setState(() {
              _q.clear();
              _minCtl.clear();
              _maxCtl.clear();
              status = LedgerStatus.open;
              sort = LedgerSort.dateDesc;
              range = null;
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<DebtEntry>>(
        future: _f,
        builder: (_, snap) {
          final all = snap.data ?? [];
          final list = _applyFilters(all);

          return Column(
            children: [
              _filtersBar(list),
              const Divider(height: 1),
              if (snap.connectionState == ConnectionState.waiting)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const Expanded(child: Center(child: Text('Kayıt yok')))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _item(list[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filtersBar(List<DebtEntry> current) {
    final openCount = current.where((e) => !e.settled).length;
    final overdueCount = current.where((e) => e.isOverdue).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _q,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Müşteri adı/telefon ara...'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _exportCsv(_applyFilters(current)),
                    icon: const Icon(Icons.file_download),
                    label: const Text('CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Açık'),
                    selected: status == LedgerStatus.open,
                    onSelected: (_) =>
                        setState(() => status = LedgerStatus.open),
                  ),
                  ChoiceChip(
                    label: Text('Vadesi Geçmiş ($overdueCount)'),
                    selected: status == LedgerStatus.overdue,
                    onSelected: (_) =>
                        setState(() => status = LedgerStatus.overdue),
                  ),
                  ChoiceChip(
                    label: const Text('Kapalı'),
                    selected: status == LedgerStatus.settled,
                    onSelected: (_) =>
                        setState(() => status = LedgerStatus.settled),
                  ),
                  ChoiceChip(
                    label: Text('Hepsi (${current.length})'),
                    selected: status == LedgerStatus.all,
                    onSelected: (_) =>
                        setState(() => status = LedgerStatus.all),
                  ),
                  const SizedBox(width: 12),
                  const Text('Sırala:'),
                  DropdownButton<LedgerSort>(
                    value: sort,
                    onChanged: (v) =>
                        setState(() => sort = v ?? LedgerSort.dateDesc),
                    items: const [
                      DropdownMenuItem(
                          value: LedgerSort.dateDesc,
                          child: Text('Tarih (yeni → eski)')),
                      DropdownMenuItem(
                          value: LedgerSort.dateAsc,
                          child: Text('Tarih (eski → yeni)')),
                      DropdownMenuItem(
                          value: LedgerSort.amountDesc,
                          child: Text('Tutar (yüksek → düşük)')),
                      DropdownMenuItem(
                          value: LedgerSort.amountAsc,
                          child: Text('Tutar (düşük → yüksek)')),
                      DropdownMenuItem(
                          value: LedgerSort.dueAsc,
                          child: Text('Vade (erken → geç)')),
                      DropdownMenuItem(
                          value: LedgerSort.dueDesc,
                          child: Text('Vade (geç → erken)')),
                      DropdownMenuItem(
                          value: LedgerSort.nameAsc, child: Text('İsim (A→Z)')),
                      DropdownMenuItem(
                          value: LedgerSort.nameDesc,
                          child: Text('İsim (Z→A)')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          prefixText: '₺ ', labelText: 'Min tutar'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          prefixText: '₺ ', labelText: 'Max tutar'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 1, 1),
                        initialDateRange: range ??
                            DateTimeRange(
                              start: now.subtract(const Duration(days: 30)),
                              end: now,
                            ),
                      );
                      if (picked != null) setState(() => range = picked);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(range == null
                        ? 'Tarih aralığı'
                        : '${range!.start.toString().substring(0, 10)} → ${range!.end.toString().substring(0, 10)}'),
                  ),
                  if (range != null)
                    IconButton(
                      tooltip: 'Tarih sıfırla',
                      onPressed: () => setState(() => range = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(DebtEntry e) {
    final isOver = e.isOverdue;
    final color = isOver
        ? Colors.red.withOpacity(.1)
        : (e.settled ? Colors.green.withOpacity(.08) : Colors.transparent);

    return Container(
      color: color,
      child: ListTile(
        title: Text(e.customerName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(label: Text('Tutar: ${e.amount.toStringAsFixed(2)}')),
              if (e.paid > 0)
                Chip(label: Text('Tahsil: ${e.paid.toStringAsFixed(2)}')),
              if (!e.settled)
                Chip(label: Text('Kalan: ${e.remaining.toStringAsFixed(2)}')),
              if (e.phone != null && e.phone!.isNotEmpty)
                Chip(label: Text('Tel: ${e.phone}')),
              if (e.dueDate != null)
                Chip(
                  label:
                      Text('Vade: ${e.dueDate!.toString().substring(0, 10)}'),
                  avatar: Icon(
                      isOver ? Icons.warning_amber_rounded : Icons.event,
                      size: 18),
                ),
              if (e.settled)
                const Chip(
                  label: Text('Kapandı'),
                  avatar: Icon(Icons.check_circle, size: 18),
                ),
            ],
          ),
        ),
        isThreeLine: (e.note != null && e.note!.isNotEmpty),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'pay') {
              await _addPayment(e);
            } else if (v == 'due') {
              await _setDue(e);
            } else if (v == 'settle') {
              await store.settle(e.id);
              if (mounted) _refresh();
            } else if (v == 'edit') {
              await _edit(e);
            } else if (v == 'delete') {
              await store.remove(e.id);
              if (mounted) _refresh();
            }
          },
          itemBuilder: (_) => [
            if (!e.settled)
              const PopupMenuItem(
                  value: 'pay',
                  child: ListTile(
                      leading: Icon(Icons.payments),
                      title: Text('Kısmi Tahsilat'))),
            const PopupMenuItem(
                value: 'due',
                child: ListTile(
                    leading: Icon(Icons.event), title: Text('Vade Tarihi'))),
            if (!e.settled)
              const PopupMenuItem(
                  value: 'settle',
                  child: ListTile(
                      leading: Icon(Icons.done_all),
                      title: Text('Tam Tahsil (Kapat)'))),
            const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit), title: Text('Düzenle'))),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete_outline), title: Text('Sil'))),
          ],
        ),
      ),
    );
  }
}
