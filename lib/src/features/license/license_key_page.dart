import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/license_service.dart';

class LicenseKeyPage extends StatefulWidget {
  const LicenseKeyPage({super.key});
  @override
  State<LicenseKeyPage> createState() => _LicenseKeyPageState();
}

class _LicenseKeyPageState extends State<LicenseKeyPage> {
  final _svc = LicenseService();
  final _ctl = TextEditingController();
  LicenseInfo _info = const LicenseInfo();

  String? _inlineMsg;
  Color? _inlineColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = await _svc.current();
    if (!mounted) return;
    setState(() => _info = i);
  }

  Future<void> _activate() async {
    final key = _ctl.text.trim();
    if (key.isEmpty) {
      _showInline('Lütfen anahtarı yapıştırın.', Colors.red);
      return;
    }
    final err = await _svc.verifyAndSave(key);
    if (!mounted) return;
    if (err != null) {
      _showInline(_friendly(err), Colors.red);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(err))));
    } else {
      _showInline('Abonelik aktif edildi.', Colors.green);
      await _load();
      _ctl.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Abonelik aktif.')));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) {
      _showInline('Panoda metin bulunamadı.', Colors.orange);
      return;
    }
    _ctl.text = t;
    _quickCheck(t);
  }

  void _clear() {
    _ctl.clear();
    _showInline(null, null);
  }

  // Anlık biçim kontrolü (yalnızca kullanıcıya rehberlik eder)
  void _quickCheck(String input) {
    final normalized = input.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    if (normalized.isEmpty) return _showInline(null, null);

    if (!normalized.contains('-')) {
      return _showInline(
          'Anahtar eksik görünüyor. Tamamını kopyaladığınızdan emin olun.',
          Colors.orange);
    }

    final idx = normalized.lastIndexOf('-');
    final payloadB64 = normalized.substring(0, idx);

    try {
      // base64url decode (padding ekle)
      var t = payloadB64;
      final mod = t.length % 4;
      if (mod != 0) t += '=' * (4 - mod);
      final bytes = base64Url.decode(t);
      final payload = utf8.decode(bytes);

      final parts = payload.split('|'); // expEpoch|edition|uid
      if (parts.isNotEmpty) {
        final expEpoch = int.tryParse(parts[0]);
        if (expEpoch != null) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(expEpoch);
          if (expiry.isBefore(DateTime.now())) {
            return _showInline(
                'Anahtarın süresi geçmiş görünüyor.', Colors.red);
          } else {
            final left = expiry.difference(DateTime.now()).inDays;
            return _showInline(
                'Anahtar biçimi uygun. (Bitiş: ${_fmt(expiry)}, ~${left} gün)',
                Colors.green);
          }
        }
      }
      _showInline('Anahtar biçimi uygun görünüyor.', Colors.green);
    } catch (_) {
      _showInline(
          'Anahtar okunamadı. Lütfen eksiksiz yapıştırın.', Colors.orange);
    }
  }

  void _showInline(String? msg, Color? c) {
    setState(() {
      _inlineMsg = msg;
      _inlineColor = c;
    });
  }

  String _friendly(String err) {
    switch (err) {
      case 'Anahtar formatı hatalı':
        return 'Anahtar formatı hatalı. Lütfen anahtarı eksiksiz yapıştırın.';
      case 'Anahtar çözümlenemedi':
        return 'Anahtar çözümlenemedi. Lütfen tekrar deneyin.';
      case 'Anahtar içeriği hatalı':
        return 'Anahtar içeriği hatalı.';
      case 'Son kullanma tarihi okunamadı':
        return 'Anahtarın tarihi okunamadı.';
      case 'Anahtar geçersiz':
        return 'Anahtar doğrulanamadı. Satın aldığınız anahtarı kullanın.';
      case 'Abonelik süresi dolmuş':
        return 'Abonelik süresi dolmuş. Yeni anahtar gereklidir.';
      default:
        return err;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _info.isActive;
    final expText = _info.expiry != null ? _fmt(_info.expiry!) : '-';
    final left = _info.remainingDays;

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik / Anahtar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // DURUM
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.verified_user : Icons.lock_outline,
                    color: isActive ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive ? 'Abonelik Aktif' : 'Abonelik Pasif',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive
                              ? 'Bitiş: $expText  •  Kalan gün: $left'
                              : 'Aboneliği aktifleştirmek için anahtar girin.',
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await LicenseService().clear();
                      await _load();
                      if (mounted) {
                        _showInline('Anahtar temizlendi.', Colors.orange);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Anahtar temizlendi.')),
                        );
                      }
                    },
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ANAHTAR GİRİŞ
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1) Anahtarı yapıştırın',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctl,
                    keyboardType: TextInputType.visiblePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    style: const TextStyle(
                        fontFamily: 'monospace', letterSpacing: 0.6),
                    decoration: InputDecoration(
                      hintText: 'ör. ZXhhbXBsZVBheWxvYWQ-abc12345',
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              tooltip: 'Yapıştır',
                              onPressed: _paste,
                              icon: const Icon(Icons.content_paste)),
                          IconButton(
                              tooltip: 'Temizle',
                              onPressed: _clear,
                              icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    onChanged: _quickCheck,
                  ),
                  if (_inlineMsg != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (_inlineColor ?? Colors.blue).withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                (_inlineColor ?? Colors.blue).withOpacity(.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _inlineColor == Colors.red
                                ? Icons.error_outline
                                : _inlineColor == Colors.orange
                                    ? Icons.info_outline
                                    : Icons.check_circle_outline,
                            color: _inlineColor ?? Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_inlineMsg!)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                            'İpucu: Anahtar e-posta/SMS ile gelir. Kopyala-yapıştır yeterlidir.',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                          onPressed: _activate,
                          icon: const Icon(Icons.verified),
                          label: const Text('Aktif Et')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // KISA BİLGİ
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kısa Bilgi',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  _Bullet('Satın alımdan sonra size bir anahtar verilir.'),
                  _Bullet('Bu sayfada anahtarı yapıştırıp “Aktif Et”e basın.'),
                  _Bullet(
                      'Abonelik bitince yeni anahtar girerek uzatabilirsiniz.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
