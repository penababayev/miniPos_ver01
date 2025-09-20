import 'package:hive_flutter/hive_flutter.dart';

class DebtEntry {
  final String id; // ms epoch string
  final int saleId; // Isar sale.id
  String customerName;
  String? phone;
  String? note;
  double amount; // toplam borç (indirim sonrası)
  double paid; // kısmi tahsil toplamı
  final DateTime createdAt;
  bool settled;
  DateTime? settledAt;
  DateTime? dueDate; // vade tarihi (opsiyonel)

  DebtEntry({
    required this.id,
    required this.saleId,
    required this.customerName,
    required this.amount,
    this.phone,
    this.note,
    required this.createdAt,
    this.paid = 0.0,
    this.settled = false,
    this.settledAt,
    this.dueDate,
  });

  double get remaining => (amount - paid).clamp(0, double.infinity);
  bool get isOverdue =>
      !settled && dueDate != null && dueDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'saleId': saleId,
        'customerName': customerName,
        'phone': phone,
        'note': note,
        'amount': amount,
        'paid': paid,
        'createdAt': createdAt.toIso8601String(),
        'settled': settled,
        'settledAt': settledAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory DebtEntry.fromMap(Map m) => DebtEntry(
        id: m['id'] as String,
        saleId: (m['saleId'] as num).toInt(),
        customerName: m['customerName'] as String,
        phone: m['phone'] as String?,
        note: m['note'] as String?,
        amount: (m['amount'] as num).toDouble(),
        paid: (m['paid'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(m['createdAt'] as String),
        settled: (m['settled'] as bool?) ?? false,
        settledAt: m['settledAt'] != null
            ? DateTime.parse(m['settledAt'] as String)
            : null,
        dueDate: m['dueDate'] != null
            ? DateTime.parse(m['dueDate'] as String)
            : null,
      );
}

class DebtLedgerStore {
  static final DebtLedgerStore _i = DebtLedgerStore._();
  DebtLedgerStore._();
  factory DebtLedgerStore() => _i;

  Box? _box;

  Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox('debt_ledger');
  }

  String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> add(DebtEntry e) async {
    await init();
    await _box!.put(e.id, e.toMap());
  }

  Future<List<DebtEntry>> list() async {
    await init();
    final list = <DebtEntry>[];
    for (final v in _box!.toMap().values) {
      if (v is Map) list.add(DebtEntry.fromMap(v));
    }
    // açıklar üstte, sonra tarihe göre (yeni → eski)
    list.sort((a, b) {
      if (a.settled != b.settled) return a.settled ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> remove(String id) async {
    await init();
    await _box!.delete(id);
  }

  Future<void> settle(String id) async {
    await init();
    final raw = _box!.get(id);
    if (raw is Map) {
      final e = DebtEntry.fromMap(raw);
      e.paid = e.amount;
      e.settled = true;
      e.settledAt = DateTime.now();
      await _box!.put(id, e.toMap());
    }
  }

  Future<void> addPayment(String id, double value) async {
    await init();
    final raw = _box!.get(id);
    if (raw is Map) {
      final e = DebtEntry.fromMap(raw);
      e.paid = (e.paid + (value < 0 ? 0 : value)).clamp(0, e.amount);
      if (e.paid >= e.amount) {
        e.settled = true;
        e.settledAt = DateTime.now();
      }
      await _box!.put(id, e.toMap());
    }
  }

  Future<void> setDueDate(String id, DateTime? due) async {
    await init();
    final raw = _box!.get(id);
    if (raw is Map) {
      final e = DebtEntry.fromMap(raw);
      e.dueDate = due;
      await _box!.put(id, e.toMap());
    }
  }

  Future<void> updateDetails(
    String id, {
    String? customerName,
    String? phone,
    String? note,
    double? amount, // gerekirse düzeltme
  }) async {
    await init();
    final raw = _box!.get(id);
    if (raw is Map) {
      final e = DebtEntry.fromMap(raw);
      if (customerName != null) e.customerName = customerName;
      if (phone != null) e.phone = phone;
      if (note != null) e.note = note;
      if (amount != null && amount >= 0) {
        e.amount = amount;
        if (e.paid > e.amount) {
          e.paid = e.amount;
        }
        e.settled = e.paid >= e.amount;
        e.settledAt = e.settled ? (e.settledAt ?? DateTime.now()) : null;
      }
      await _box!.put(id, e.toMap());
    }
  }
}
