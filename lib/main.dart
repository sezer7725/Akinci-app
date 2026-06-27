// ============================================================
//  AKINCI KOMUTA MERKEZI - main.dart
//  v1: Giris + Genel ekran (panel.py koprusune bagli)
// ============================================================
//  BAGLANTI: Telefonda calisan panel.py -> http://127.0.0.1:8080
//    /durum -> bakiye, acik pozisyonlar, PNL, istatistik, bot aktif mi
//
//  GIRIS BILGISI (su an sabit, sonra degistirilebilir):
//    Kullanici: AkinciV1   Sifre: akinci77
//
//  NOT: Tek dosya (senin icin basit). GitHub Actions ile APK'ya derlenir.
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AkinciApp());
}

// ---- Renk paleti (mockup'tan birebir) ----
class Renk {
  static const arkaplan   = Color(0xFF0B1320); // koyu lacivert
  static const kart       = Color(0xFF111C2E); // kart zemini
  static const kartAcik   = Color(0xFF16233A); // hafif acik kart
  static const teal       = Color(0xFF00F0B5); // ana vurgu (yesil-teal)
  static const mavi       = Color(0xFF00C2FF); // ikincil
  static const kirmizi    = Color(0xFFFF4D4D); // zarar/uyari
  static const altin      = Color(0xFFF5C542); // dikkat
  static const yazi       = Color(0xFFE6EDF5); // ana yazi
  static const yaziSoluk  = Color(0xFF7C8BA1); // ikincil yazi
  static const cizgi      = Color(0xFF1E2B40); // ayrac
}

// ---- Giris bilgisi (sabit) ----
const String kKullanici = "AkinciV1";
const String kSifre     = "akinci77";

// ---- Panel adresi ----
const String kPanelUrl = "http://127.0.0.1:8080";

class AkinciApp extends StatelessWidget {
  const AkinciApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akinci Komuta Merkezi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Renk.arkaplan,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Renk.teal,
          surface: Renk.kart,
        ),
      ),
      home: const GirisEkrani(),
    );
  }
}

// ============================================================
//  GIRIS EKRANI
// ============================================================
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _kullaniciCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  String? _hata;
  bool _yukleniyor = false;
  bool _beniHatirla = false;

  @override
  void initState() {
    super.initState();
    _kayitliBilgiYukle();
  }

  // Kayitli giris bilgisi varsa yukle; "beni hatirla" isaretliyse otomatik gir
  Future<void> _kayitliBilgiYukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final hatirla = p.getBool('beni_hatirla') ?? false;
      if (hatirla) {
        final k = p.getString('kullanici') ?? '';
        final s = p.getString('sifre') ?? '';
        if (k == kKullanici && s == kSifre) {
          // dogru bilgi kayitli -> direkt panele gec
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AnaKabuk()),
            );
          }
          return;
        }
      }
      // hatirla kapali ama kullanici adi dolduralim (kolaylik)
      if (mounted) {
        setState(() {
          _kullaniciCtrl.text = p.getString('kullanici') ?? '';
          _beniHatirla = hatirla;
        });
      }
    } catch (_) {}
  }

  void _girisYap() async {
    setState(() { _hata = null; _yukleniyor = true; });
    // Kucuk bir gecikme (his icin) + dogrulama
    await Future.delayed(const Duration(milliseconds: 300));
    final k = _kullaniciCtrl.text.trim();
    final s = _sifreCtrl.text;
    if (k == kKullanici && s == kSifre) {
      HapticFeedback.mediumImpact();
      // beni hatirla durumunu kaydet
      try {
        final p = await SharedPreferences.getInstance();
        await p.setBool('beni_hatirla', _beniHatirla);
        if (_beniHatirla) {
          await p.setString('kullanici', k);
          await p.setString('sifre', s);
        } else {
          await p.remove('sifre');  // sifreyi tutma, sadece kullanici adi kalsin
          await p.setString('kullanici', k);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AnaKabuk()),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _hata = "Kullanici adi veya sifre yanlis"; _yukleniyor = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- ARKA PLAN: turkuaz kod yagmuru (Matrix tarzi) ---
          const Positioned.fill(child: KodYagmuru()),
          // --- hafif karartma (yazilar net okunsun) ---
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Renk.arkaplan.withOpacity(0.55),
                    Renk.arkaplan.withOpacity(0.80),
                    Renk.arkaplan.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),
          // --- ON PLAN: logo + form ---
          SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // --- Logo (rozet stili, gercek logo asset gelince degisecek) ---
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF13233C), Color(0xFF0B1320)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Renk.teal.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Renk.teal.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined, color: Renk.teal, size: 56),
                ),
                const SizedBox(height: 28),
                const Text("AKINCI",
                  style: TextStyle(color: Renk.yazi, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 8)),
                const SizedBox(height: 6),
                Text("KOMUTA MERKEZI",
                  style: TextStyle(color: Renk.yaziSoluk, fontSize: 13, letterSpacing: 5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 44),
                // --- Kullanici adi ---
                _girisAlani(_kullaniciCtrl, "Kullanici adi", Icons.person_outline, false),
                const SizedBox(height: 14),
                // --- Sifre ---
                _girisAlani(_sifreCtrl, "Sifre", Icons.lock_outline, true),
                const SizedBox(height: 6),
                // --- Beni hatirla ---
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _beniHatirla = !_beniHatirla);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _beniHatirla ? Renk.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _beniHatirla ? Renk.teal : Renk.yaziSoluk.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: _beniHatirla
                          ? const Icon(Icons.check, color: Renk.arkaplan, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text("Beni hatirla",
                        style: TextStyle(color: Renk.yaziSoluk, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
                if (_hata != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(Icons.error_outline, color: Renk.kirmizi, size: 18),
                    const SizedBox(width: 8),
                    Text(_hata!, style: const TextStyle(color: Renk.kirmizi, fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 28),
                // --- Giris butonu ---
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _yukleniyor ? null : _girisYap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renk.teal,
                      foregroundColor: Renk.arkaplan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _yukleniyor
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Renk.arkaplan))
                      : const Text("GIRIS YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Renk.teal, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text("guvenli baglanti · v1.0", style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _girisAlani(TextEditingController ctrl, String ipucu, IconData ikon, bool gizli) {
    return Container(
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Renk.cizgi, width: 1),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: gizli,
        style: const TextStyle(color: Renk.yazi, fontSize: 15),
        decoration: InputDecoration(
          hintText: ipucu,
          hintStyle: const TextStyle(color: Renk.yaziSoluk),
          prefixIcon: Icon(ikon, color: Renk.yaziSoluk, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        ),
      ),
    );
  }
}

// ============================================================
//  ANA KABUK (alt sekme cubugu - su an sadece Genel dolu)
// ============================================================
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});
  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _sekme = 0;

  @override
  Widget build(BuildContext context) {
    // v1: sadece Genel ekrani dolu; digerleri "yakinda"
    final ekranlar = [
      const GenelEkrani(),
      const _YakindaEkrani(baslik: "CANLI GRAFIK"),
      const PozisyonEkrani(),
      const _YakindaEkrani(baslik: "MESAJ & ASISTAN"),
    ];
    return Scaffold(
      body: ekranlar[_sekme],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Renk.kart,
          border: Border(top: BorderSide(color: Renk.cizgi, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _sekme,
          onTap: (i) { HapticFeedback.selectionClick(); setState(() => _sekme = i); },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Renk.teal,
          unselectedItemColor: Renk.yaziSoluk,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "GENEL"),
            BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart_outlined), label: "GRAFIK"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: "POZISYON"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "MESAJ"),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  GENEL EKRANI (canli veri - panel.py'den)
// ============================================================
class GenelEkrani extends StatefulWidget {
  const GenelEkrani({super.key});
  @override
  State<GenelEkrani> createState() => _GenelEkraniState();
}

class _GenelEkraniState extends State<GenelEkrani> {
  Map<String, dynamic>? _durum;
  String? _hata;
  bool _ilkYukleme = true;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _veriCek();
    // Her 5 saniyede bir guncelle
    _zamanlayici = Timer.periodic(const Duration(seconds: 5), (_) => _veriCek());
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  Future<void> _veriCek() async {
    try {
      final r = await http.get(Uri.parse("$kPanelUrl/durum"))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        setState(() {
          _durum = json.decode(utf8.decode(r.bodyBytes));
          _hata = null;
          _ilkYukleme = false;
        });
      } else {
        setState(() { _hata = "Panel cevap vermedi (${r.statusCode})"; _ilkYukleme = false; });
      }
    } catch (e) {
      setState(() {
        _hata = "Panele baglanilamadi";
        _ilkYukleme = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: Renk.teal,
        backgroundColor: Renk.kart,
        onRefresh: _veriCek,
        child: _ilkYukleme
          ? const Center(child: CircularProgressIndicator(color: Renk.teal))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _baslik(),
                const SizedBox(height: 20),
                if (_hata != null) _hataKarti(),
                if (_durum != null) ..._icerik(),
              ],
            ),
      ),
    );
  }

  // --- Ust baslik (logo + AKINCI + canli rozet) ---
  Widget _baslik() {
    final aktif = _durum?['bot_aktif'] == true;
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Renk.kartAcik,
          border: Border.all(color: Renk.teal.withOpacity(0.3)),
        ),
        child: const Icon(Icons.shield_outlined, color: Renk.teal, size: 24),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text("AKINCI", style: TextStyle(color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2)),
        Text("KOMUTA MERKEZI", style: TextStyle(color: Renk.yaziSoluk, fontSize: 10, letterSpacing: 2)),
      ]),
      const Spacer(),
      _rozet(aktif ? "CANLI" : "DURDU", aktif ? Renk.teal : Renk.kirmizi),
    ]);
  }

  Widget _rozet(String yazi, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(yazi, style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ]),
    );
  }

  Widget _hataKarti() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Renk.kirmizi.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.kirmizi.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off, color: Renk.kirmizi, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_hata!, style: const TextStyle(color: Renk.kirmizi, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text("panel.py calisiyor mu? (Termux'ta python panel.py)",
            style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
        ])),
      ]),
    );
  }

  List<Widget> _icerik() {
    final d = _durum!;
    final bakiye = (d['bakiye'] ?? 0).toDouble();
    final acikPnl = (d['acik_pnl'] ?? 0).toDouble();
    final pozlar = (d['acik_pozisyon'] ?? []) as List;
    final ist = d['istatistik'] ?? {};
    final isabet = (ist['isabet_yuzde'] ?? 0).toDouble();
    final acikSayi = d['acik_sayi'] ?? 0;

    return [
      // --- Bakiye + PNL satiri ---
      Row(children: [
        Expanded(child: _kutu("BAKIYE", "\$${_vir(bakiye)}", Renk.yazi, altYazi: "canli")),
        const SizedBox(width: 12),
        Expanded(child: _kutu("ACIK PNL", "${acikPnl >= 0 ? '+' : ''}\$${_vir(acikPnl)}",
          acikPnl >= 0 ? Renk.teal : Renk.kirmizi)),
      ]),
      const SizedBox(height: 12),
      // --- Acik pozisyon + isabet ---
      Row(children: [
        Expanded(child: _kutu("ACIK POZISYON", "$acikSayi / 4", Renk.yazi)),
        const SizedBox(width: 12),
        Expanded(child: _kutu("ISABET ORANI", "%${isabet.toStringAsFixed(0)}",
          isabet >= 50 ? Renk.teal : Renk.altin)),
      ]),
      const SizedBox(height: 20),
      // --- Acik pozisyonlar listesi ---
      _bolumBaslik("ACIK POZISYONLAR"),
      const SizedBox(height: 10),
      if (pozlar.isEmpty)
        _bosPozisyon()
      else
        ...pozlar.map((p) => _pozisyonKarti(p)).toList(),
      const SizedBox(height: 20),
      // --- Kontrol butonlari ---
      _bolumBaslik("KONTROL"),
      const SizedBox(height: 10),
      _kontrolButonu("OPERASYONU DURDUR", Icons.pause_circle_outline, Renk.altin, _durdurOnay),
      const SizedBox(height: 10),
      _kontrolButonu("ACIL TAHLIYE", Icons.warning_amber_rounded, Renk.kirmizi, _acilOnay),
      const SizedBox(height: 20),
    ];
  }

  Widget _kutu(String etiket, String deger, Color renk, {String? altYazi}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(deger, style: TextStyle(color: renk, fontSize: 22, fontWeight: FontWeight.w700)),
        if (altYazi != null) ...[
          const SizedBox(height: 2),
          Text(altYazi, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 10)),
        ],
      ]),
    );
  }

  Widget _bolumBaslik(String yazi) {
    return Text(yazi, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600));
  }

  Widget _bosPozisyon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(children: [
        Icon(Icons.inbox_outlined, color: Renk.yaziSoluk.withOpacity(0.5), size: 36),
        const SizedBox(height: 10),
        Text("Acik pozisyon yok", style: TextStyle(color: Renk.yaziSoluk, fontSize: 14)),
        const SizedBox(height: 4),
        Text("Bot uygun sinyal bekliyor", style: TextStyle(color: Renk.yaziSoluk.withOpacity(0.6), fontSize: 12)),
      ]),
    );
  }

  Widget _pozisyonKarti(dynamic p) {
    final yon = p['yon'] ?? '?';
    final long = yon == 'LONG';
    final pnl = (p['pnl'] ?? 0).toDouble();
    final yuzde = (p['yuzde'] ?? 0).toDouble();
    final karda = pnl >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (karda ? Renk.teal : Renk.kirmizi).withOpacity(0.25)),
      ),
      child: Column(children: [
        Row(children: [
          // yon rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (long ? Renk.teal : Renk.kirmizi).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(yon, style: TextStyle(color: long ? Renk.teal : Renk.kirmizi, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Text(p['sembol'] ?? '', style: const TextStyle(color: Renk.yazi, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text("${karda ? '+' : ''}\$${_vir(pnl)}",
              style: TextStyle(color: karda ? Renk.teal : Renk.kirmizi, fontSize: 15, fontWeight: FontWeight.w700)),
            Text("${karda ? '+' : ''}${yuzde.toStringAsFixed(2)}%",
              style: TextStyle(color: karda ? Renk.teal : Renk.kirmizi, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _pozBilgi("Giris", "\$${p['giris']}"),
          _pozBilgi("Mark", "\$${p['mark']}"),
          _pozBilgi("Stop", "\$${p['stop']}"),
        ]),
      ]),
    );
  }

  Widget _pozBilgi(String etiket, String deger) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiket, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 10)),
      const SizedBox(height: 2),
      Text(deger, style: const TextStyle(color: Renk.yazi, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _kontrolButonu(String yazi, IconData ikon, Color renk, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, color: renk, size: 20),
        label: Text(yazi, style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        style: OutlinedButton.styleFrom(
          backgroundColor: renk.withOpacity(0.06),
          side: BorderSide(color: renk.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // --- Onaylar (su an sadece uyari; gercek dur/kapat bekci.py ile sonra) ---
  void _durdurOnay() {
    HapticFeedback.mediumImpact();
    _onayDialog(
      "Operasyonu Durdur",
      "Bot yeni islem acmayi durduracak. Acik pozisyonlar devam eder. Emin misin?",
      Renk.altin,
      () {
        Navigator.pop(context);
        _bilgiMesaji("Bu ozellik yakinda (bekci.py baglaninca)");
      },
    );
  }

  void _acilOnay() {
    HapticFeedback.heavyImpact();
    _onayDialog(
      "ACIL TAHLIYE",
      "TUM acik pozisyonlar PIYASA fiyatindan KAPATILACAK. Bu islem geri alinamaz. Emin misin?",
      Renk.kirmizi,
      () {
        Navigator.pop(context);
        _bilgiMesaji("Bu ozellik yakinda (bekci.py baglaninca)");
      },
    );
  }

  void _onayDialog(String baslik, String mesaj, Color renk, VoidCallback onay) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Renk.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(baslik, style: TextStyle(color: renk, fontWeight: FontWeight.w700)),
        content: Text(mesaj, style: const TextStyle(color: Renk.yazi, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text("Vazgec", style: TextStyle(color: Renk.yaziSoluk))),
          ElevatedButton(onPressed: onay,
            style: ElevatedButton.styleFrom(backgroundColor: renk, foregroundColor: Renk.arkaplan),
            child: const Text("Onayla", style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _bilgiMesaji(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mesaj),
      backgroundColor: Renk.kartAcik,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // binliklere virgul (basit)
  String _vir(double sayi) {
    final s = sayi.abs().toStringAsFixed(2);
    final parcalar = s.split('.');
    final tamKisim = parcalar[0];
    final ondalik = parcalar[1];
    final tampon = StringBuffer();
    for (int i = 0; i < tamKisim.length; i++) {
      if (i > 0 && (tamKisim.length - i) % 3 == 0) tampon.write(',');
      tampon.write(tamKisim[i]);
    }
    return "$tampon.$ondalik";
  }
}

// ============================================================
//  YAKINDA EKRANI (Grafik/Pozisyon/Mesaj - v1'de bos)
// ============================================================
class _YakindaEkrani extends StatelessWidget {
  final String baslik;
  const _YakindaEkrani({required this.baslik});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.construction_outlined, color: Renk.yaziSoluk.withOpacity(0.4), size: 56),
          const SizedBox(height: 16),
          Text(baslik, style: const TextStyle(color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text("yakinda", style: TextStyle(color: Renk.yaziSoluk, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ============================================================
//  POZISYON EKRANI - acik pozisyonlarin detayli listesi
//  panel.py /durum'dan acik_pozisyon listesini ceker (5sn'de bir),
//  her pozisyonu zengin bir kartta gosterir: yon, giris, mark, stop,
//  hedef, kaldirac, senaryo, kar/zarar + stop'a ve hedefe uzaklik %.
// ============================================================
class PozisyonEkrani extends StatefulWidget {
  const PozisyonEkrani({super.key});
  @override
  State<PozisyonEkrani> createState() => _PozisyonEkraniState();
}

class _PozisyonEkraniState extends State<PozisyonEkrani> {
  List<dynamic> _pozlar = [];
  bool _yukleniyor = true;
  bool _hata = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cek();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _cek());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cek() async {
    try {
      final r = await http.get(Uri.parse("$kPanelUrl/durum"))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final d = json.decode(utf8.decode(r.bodyBytes));
        if (mounted) {
          setState(() {
            _pozlar = (d['acik_pozisyon'] as List?) ?? [];
            _yukleniyor = false;
            _hata = false;
          });
        }
      } else {
        if (mounted) setState(() { _hata = true; _yukleniyor = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _hata = true; _yukleniyor = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // baslik
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            const Text("ACIK POZISYONLAR",
                style: TextStyle(color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Renk.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("${_pozlar.length} / 4",
                  style: const TextStyle(color: Renk.teal, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator(color: Renk.teal))
              : _hata
                  ? _hataKutu()
                  : _pozlar.isEmpty
                      ? _bosKutu()
                      : RefreshIndicator(
                          color: Renk.teal,
                          backgroundColor: Renk.kart,
                          onRefresh: _cek,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: _pozlar.length,
                            itemBuilder: (c, i) => _pozKarti(_pozlar[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _pozKarti(dynamic p) {
    final yon = (p['yon'] ?? '?').toString();
    final long = yon == 'LONG';
    final pnl = (p['pnl'] ?? 0).toDouble();
    final yuzde = (p['yuzde'] ?? 0).toDouble();
    final karda = pnl >= 0;
    final renk = long ? Renk.teal : Renk.kirmizi;
    final pnlRenk = karda ? Renk.teal : Renk.kirmizi;

    final giris = (p['giris'] ?? 0).toDouble();
    final mark = (p['mark'] ?? 0).toDouble();
    final stop = (p['stop'] ?? 0).toDouble();
    final hedef = (p['hedef'] ?? 0).toDouble();
    final kaldirac = p['kaldirac'];
    final senaryo = (p['senaryo'] ?? '').toString();

    // stop'a ve hedefe uzaklik % (mark'a gore)
    String stopUz = "-";
    String hedefUz = "-";
    if (mark > 0 && stop > 0) {
      stopUz = "${((stop - mark) / mark * 100).abs().toStringAsFixed(2)}%";
    }
    if (mark > 0 && hedef > 0) {
      hedefUz = "${((hedef - mark) / mark * 100).abs().toStringAsFixed(2)}%";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renk.withOpacity(0.3)),
      ),
      child: Column(children: [
        // ust satir: yon + sembol + pnl
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: renk.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(children: [
                Icon(long ? Icons.trending_up : Icons.trending_down, color: renk, size: 14),
                const SizedBox(width: 4),
                Text(yon, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 10),
            Text(p['sembol'] ?? '', style: const TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w700)),
            if (kaldirac != null && kaldirac != 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Renk.yaziSoluk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text("${kaldirac}x", style: const TextStyle(color: Renk.yaziSoluk, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("${karda ? '+' : ''}\$${_v(pnl)}",
                  style: TextStyle(color: pnlRenk, fontSize: 17, fontWeight: FontWeight.w700)),
              Text("${karda ? '+' : ''}${yuzde.toStringAsFixed(2)}%",
                  style: TextStyle(color: pnlRenk, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        Divider(color: Renk.cizgi, height: 1),
        // alt: fiyat detaylari
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _bilgi("GIRIS", "\$${_f(giris)}", Renk.yazi)),
              Expanded(child: _bilgi("ANLIK", "\$${_f(mark)}", karda ? Renk.teal : Renk.kirmizi)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _bilgi("STOP", "\$${_f(stop)}", Renk.kirmizi, alt: "uzaklik $stopUz")),
              Expanded(child: _bilgi("HEDEF", hedef > 0 ? "\$${_f(hedef)}" : "trailing", Renk.altin, alt: hedef > 0 ? "uzaklik $hedefUz" : "tepe takip")),
            ]),
            if (senaryo.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.bookmark_outline, color: Renk.yaziSoluk, size: 14),
                const SizedBox(width: 6),
                Text("Senaryo: ", style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
                Text(senaryo, style: const TextStyle(color: Renk.mavi, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _bilgi(String etiket, String deger, Color renk, {String? alt}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiket, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 10, letterSpacing: 0.5)),
      const SizedBox(height: 3),
      Text(deger, style: TextStyle(color: renk, fontSize: 15, fontWeight: FontWeight.w700)),
      if (alt != null) ...[
        const SizedBox(height: 2),
        Text(alt, style: TextStyle(color: Renk.yaziSoluk.withOpacity(0.7), fontSize: 10)),
      ],
    ]);
  }

  Widget _bosKutu() {
    return ListView(children: [
      const SizedBox(height: 80),
      Icon(Icons.inbox_outlined, color: Renk.yaziSoluk.withOpacity(0.4), size: 56),
      const SizedBox(height: 16),
      const Center(child: Text("Acik pozisyon yok", style: TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w600))),
      const SizedBox(height: 6),
      Center(child: Text("Bot uygun sinyal bekliyor", style: TextStyle(color: Renk.yaziSoluk, fontSize: 13))),
    ]);
  }

  Widget _hataKutu() {
    return ListView(children: [
      const SizedBox(height: 80),
      Icon(Icons.cloud_off_outlined, color: Renk.kirmizi.withOpacity(0.5), size: 56),
      const SizedBox(height: 16),
      const Center(child: Text("Panele baglanilamadi", style: TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w600))),
      const SizedBox(height: 6),
      Center(child: Text("panel.py calisiyor mu?", style: TextStyle(color: Renk.yaziSoluk, fontSize: 13))),
    ]);
  }

  // sayi bicimleme
  String _v(double x) => x.toStringAsFixed(2);
  String _f(double x) {
    if (x >= 100) return x.toStringAsFixed(2);
    if (x >= 1) return x.toStringAsFixed(4);
    return x.toStringAsFixed(6);
  }
}

// ============================================================
//  KOD YAGMURU - turkuaz Matrix tarzi arka plan animasyonu
//  Giris ekraninin arkasinda yukaridan asagi akan kod/karakterler.
//  Hafif, performansli; logo ve form onde net durur.
// ============================================================
class KodYagmuru extends StatefulWidget {
  const KodYagmuru({super.key});
  @override
  State<KodYagmuru> createState() => _KodYagmuruState();
}

class _KodYagmuruState extends State<KodYagmuru> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Sutun> _sutunlar = [];
  final math.Random _rng = math.Random();
  Size _boyut = Size.zero;

  // akan karakterler (rakam + harf + sembol karisik, "kod" hissi)
  static const String _karakterler = "01<>{}[]()/*+-=;:.\$#&%abcdef0123456789ABCDEF";

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  void _sutunlariKur(Size boyut) {
    _boyut = boyut;
    _sutunlar.clear();
    const double sutunGenislik = 16; // karakter sutun araligi
    final int adet = (boyut.width / sutunGenislik).ceil();
    for (int i = 0; i < adet; i++) {
      _sutunlar.add(_Sutun(
        x: i * sutunGenislik,
        y: _rng.nextDouble() * boyut.height,
        hiz: 40 + _rng.nextDouble() * 90,        // px/sn
        uzunluk: 6 + _rng.nextInt(14),           // kuyruk uzunlugu
        karakterler: List.generate(20, (_) => _rastgeleKarakter()),
        sonGuncelleme: 0,
      ));
    }
  }

  String _rastgeleKarakter() =>
      _karakterler[_rng.nextInt(_karakterler.length)];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final boyut = Size(c.maxWidth, c.maxHeight);
      if (boyut != _boyut || _sutunlar.isEmpty) {
        _sutunlariKur(boyut);
      }
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // her karede sutunlari ilerlet
          for (final s in _sutunlar) {
            s.y += s.hiz * (1 / 60.0);  // ~60fps varsayimi
            if (s.y - s.uzunluk * 16 > boyut.height) {
              s.y = -_rng.nextDouble() * 200;
              s.hiz = 40 + _rng.nextDouble() * 90;
              // ara sira karakterleri tazele
              if (_rng.nextDouble() < 0.5) {
                s.karakterler = List.generate(20, (_) => _rastgeleKarakter());
              }
            }
          }
          return CustomPaint(
            size: boyut,
            painter: _YagmurPainter(_sutunlar),
          );
        },
      );
    });
  }
}

class _Sutun {
  double x;
  double y;
  double hiz;
  int uzunluk;
  List<String> karakterler;
  double sonGuncelleme;
  _Sutun({
    required this.x,
    required this.y,
    required this.hiz,
    required this.uzunluk,
    required this.karakterler,
    required this.sonGuncelleme,
  });
}

class _YagmurPainter extends CustomPainter {
  final List<_Sutun> sutunlar;
  _YagmurPainter(this.sutunlar);

  static const double _satirYuksek = 16;
  static const Color _teal = Color(0xFF00F0B5);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final s in sutunlar) {
      for (int i = 0; i < s.uzunluk; i++) {
        final double cy = s.y - i * _satirYuksek;
        if (cy < -_satirYuksek || cy > size.height) continue;
        // bas karakter parlak, kuyruk soluk
        double op;
        Color renk;
        if (i == 0) {
          op = 0.95; renk = Colors.white.withOpacity(op);  // bas: beyazimsi parlak
        } else {
          op = (1.0 - i / s.uzunluk) * 0.55;               // kuyruk: teal, giderek soluk
          renk = _teal.withOpacity(op.clamp(0.0, 1.0));
        }
        final ch = s.karakterler[i % s.karakterler.length];
        tp.text = TextSpan(
          text: ch,
          style: TextStyle(
            color: renk,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(s.x, cy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _YagmurPainter old) => true;
}
