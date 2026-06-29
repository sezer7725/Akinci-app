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

// ============================================================
//  DURUM SERVISI - uygulamanin merkezi veri beyni (singleton)
// ============================================================
//  NEDEN: Eskiden her ekran (Genel, Pozisyon...) ayri ayri panel'e
//  istek atiyordu. Sonuc: sekme gecisinde bekleme, tek istek
//  iskalayinca kirmizi bant titremesi, panel'in 3 kat yorulmasi.
//
//  COZUM: Tek servis arka planda surekli panel'i dinler (5sn),
//  veriyi hafizada tutar. Tum ekranlar BU servisten okur, kendileri
//  istek ATMAZ. Faydalari:
//   - Sekme gecisi ANINDA (veri zaten hazir, bekleme yok)
//   - Tek baglanti noktasi (panel rahat)
//   - Akilli kopukluk: bir istek iskalarsa SON veriyi gosterir,
//     kirmizi uyari ancak ust uste 3 iskada (~15sn) cikar -> titreme yok
//   - ChangeNotifier: veri degisince dinleyen ekranlar otomatik yenilenir
//
//  Flutter standardi, EKSTRA PAKET YOK.
// ============================================================
class DurumServisi extends ChangeNotifier {
  DurumServisi._();
  static final DurumServisi instance = DurumServisi._();

  Map<String, dynamic>? _veri;        // son basarili panel verisi
  DateTime? _sonBasari;               // en son ne zaman veri geldi
  int _ardArdaHata = 0;               // ust uste kac istek iskaladi
  bool _ilkYukleme = true;            // hic veri gelmedi mi
  Timer? _zamanlayici;
  bool _calisiyor = false;

  // --- disari acilan durum ---
  Map<String, dynamic>? get veri => _veri;
  bool get ilkYukleme => _ilkYukleme;
  // Baglanti "kopuk" sayilir: ust uste 3+ hata VE elde veri yoksa ya da
  // son basaridan 20sn+ gectiyse. Tek/iki iskada kopuk DEMEZ (titreme onleme).
  bool get bagliMi {
    if (_veri == null) return false;
    if (_sonBasari == null) return false;
    final gecen = DateTime.now().difference(_sonBasari!).inSeconds;
    return _ardArdaHata < 3 && gecen < 20;
  }
  // "kac saniye once guncellendi" (UI'da gostermek icin)
  int get saniyeOnce {
    if (_sonBasari == null) return -1;
    return DateTime.now().difference(_sonBasari!).inSeconds;
  }

  // Uygulama acilinca BIR KEZ baslatilir (AnaKabuk'tan)
  void basla() {
    if (_calisiyor) return;
    _calisiyor = true;
    _cek();
    _zamanlayici = Timer.periodic(const Duration(seconds: 5), (_) => _cek());
  }

  void durdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    _calisiyor = false;
  }

  // Kullanicinin elle yenilemesi icin (pull-to-refresh)
  Future<void> elleYenile() async => _cek();

  Future<void> _cek() async {
    try {
      final r = await http.get(Uri.parse("$kPanelUrl/durum"))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        _veri = json.decode(utf8.decode(r.bodyBytes));
        _sonBasari = DateTime.now();
        _ardArdaHata = 0;
        _ilkYukleme = false;
        notifyListeners();
        return;
      }
      _hataOldu();
    } catch (_) {
      _hataOldu();
    }
  }

  void _hataOldu() {
    _ardArdaHata++;
    _ilkYukleme = false;
    // VERIYI SILME: son basarili veri ekranda kalsin (titreme yok)
    notifyListeners();
  }
}

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
                // --- Logo (gercek kurt+kartal logosu) ---
                Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: Renk.teal.withOpacity(0.25), blurRadius: 40, spreadRadius: 4),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('logo.png', fit: BoxFit.cover),
                  ),
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
//  PANELDEN TEK SEFERLIK VERI CEKME + ORTAK YARDIMCILAR
// ============================================================
Future<dynamic> _panel(String yol) async {
  try {
    final r = await http
        .get(Uri.parse("$kPanelUrl$yol"))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) {
      return json.decode(utf8.decode(r.bodyBytes));
    }
  } catch (_) {}
  return null;
}

double _d(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0));

String _para(num v, {bool isaret = false}) {
  final govde = v.abs().toStringAsFixed(2);
  final on = isaret ? (v >= 0 ? "+" : "-") : (v < 0 ? "-" : "");
  return "$on\$$govde";
}

Color _pnlRenk(num v) => v >= 0 ? Renk.teal : Renk.kirmizi;

const TextStyle _baslikStil = TextStyle(
    color: Renk.yazi, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1);
const TextStyle _kucukBaslik = TextStyle(
    color: Renk.yaziSoluk, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1);

Widget _kart({required Widget cocuk, EdgeInsets? ic}) {
  return Container(
    padding: ic ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Renk.kart,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Renk.cizgi),
    ),
    child: cocuk,
  );
}

Widget _bosKutu(String mesaj) => _kart(
    cocuk: Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(mesaj, style: const TextStyle(color: Renk.yaziSoluk)))));

Widget _durumRozet(bool aktif) {
  final renk = aktif ? Renk.teal : Renk.kirmizi;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: renk.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: renk.withOpacity(0.5)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(aktif ? "CANLI" : "DURDU",
          style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

Widget _ustBar(BuildContext ctx, {required bool aktif, VoidCallback? cikis}) {
  return Row(children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 44, height: 44, child: Image.asset('logo.png', fit: BoxFit.cover)),
    ),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text("AKINCI",
          style: TextStyle(color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2)),
      Text("KOMUTA MERKEZI",
          style: TextStyle(color: Renk.yaziSoluk, fontSize: 10, letterSpacing: 3)),
    ]),
    const Spacer(),
    _durumRozet(aktif),
    if (cikis != null) ...[
      const SizedBox(width: 10),
      GestureDetector(
        onTap: cikis,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: Renk.kartAcik, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.logout, color: Renk.yaziSoluk, size: 18),
        ),
      ),
    ],
  ]);
}

Widget _coinSecici(List<String> coinler, String secili, void Function(String) sec) {
  return SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: coinler.map((c) {
        final aktif = c == secili;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => sec(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: aktif ? Renk.teal.withOpacity(0.15) : Renk.kart,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: aktif ? Renk.teal : Renk.cizgi),
              ),
              child: Text(c,
                  style: TextStyle(
                      color: aktif ? Renk.teal : Renk.yaziSoluk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Future<void> _cikisYap(BuildContext ctx) async {
  try {
    final p = await SharedPreferences.getInstance();
    for (final k in ["beniHatirla", "hatirla", "remember", "beni_hatirla", "autoLogin"]) {
      await p.remove(k);
    }
  } catch (_) {}
  DurumServisi.instance.durdur();
  if (ctx.mounted) {
    Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GirisEkrani()), (r) => false);
  }
}

// ============================================================
//  ANA KABUK - 4 sekme: Ana Sayfa, Grafik, AI Analiz, Mesaj
// ============================================================
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});
  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    DurumServisi.instance.basla();
  }

  void _git(int i) => setState(() => _sekme = i);

  @override
  Widget build(BuildContext context) {
    final ekranlar = [
      DashboardEkrani(onSekme: _git),
      const GrafikEkrani(),
      const AIAnalizEkrani(),
      const MesajEkrani(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _sekme, children: ekranlar)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Renk.kart,
          border: Border(top: BorderSide(color: Renk.cizgi)),
        ),
        child: BottomNavigationBar(
          currentIndex: _sekme,
          onTap: _git,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Renk.teal,
          unselectedItemColor: Renk.yaziSoluk,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "ANA SAYFA"),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "GRAFIK"),
            BottomNavigationBarItem(icon: Icon(Icons.psychology_outlined), label: "AI ANALIZ"),
            BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: "MESAJ"),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ANA SAYFA (DASHBOARD) - mockup'taki gibi
// ============================================================
class DashboardEkrani extends StatefulWidget {
  final void Function(int)? onSekme;
  const DashboardEkrani({super.key, this.onSekme});
  @override
  State<DashboardEkrani> createState() => _DashboardEkraniState();
}

class _DashboardEkraniState extends State<DashboardEkrani> {
  final _servis = DurumServisi.instance;
  List<double> _gecmis = [];
  Map<String, dynamic>? _aiOzet;
  bool _aiYukleniyor = true;

  @override
  void initState() {
    super.initState();
    _gecmisCek();
    _aiCek();
  }

  Future<void> _gecmisCek() async {
    final v = await _panel("/gecmis");
    if (v is Map && v["noktalar"] is List) {
      final n = (v["noktalar"] as List).map((e) => _d(e["v"])).toList();
      if (mounted) setState(() => _gecmis = n);
    }
  }

  Future<void> _aiCek() async {
    String coin = "BTCUSDT";
    final poz = _servis.veri?["acik_pozisyon"];
    if (poz is List && poz.isNotEmpty) {
      coin = poz.first["sembol"]?.toString() ?? coin;
    }
    final v = await _panel("/analiz?coin=$coin");
    if (mounted) {
      setState(() {
        _aiOzet = (v is Map) ? Map<String, dynamic>.from(v) : null;
        _aiYukleniyor = false;
      });
    }
  }

  Future<void> _yenile() async {
    await _servis.elleYenile();
    await _gecmisCek();
    await _aiCek();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _servis,
      builder: (context, _) {
        final v = _servis.veri;
        final aktif = (v?["bot_aktif"] == true);
        final st = (v?["istatistik"] as Map?) ?? {};
        final poz = (v?["acik_pozisyon"] as List?) ?? [];
        return RefreshIndicator(
          onRefresh: _yenile,
          color: Renk.teal,
          backgroundColor: Renk.kart,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ustBar(context, aktif: aktif, cikis: () => _cikisYap(context)),
              const SizedBox(height: 16),
              _portfoyKart(v),
              const SizedBox(height: 14),
              _metrikGrid(v, st),
              const SizedBox(height: 14),
              _aiKart(),
              const SizedBox(height: 16),
              Text("AÇIK POZISYONLAR", style: _baslikStil),
              const SizedBox(height: 10),
              if (poz.isEmpty) _bosKutu("Şu an açık pozisyon yok"),
              ...poz.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _pozKart(Map<String, dynamic>.from(p)),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _portfoyKart(Map<String, dynamic>? v) {
    final bakiye = _d(v?["bakiye"]);
    double yuzde = 0;
    if (_gecmis.length >= 2 && _gecmis.first > 0) {
      yuzde = (_gecmis.last - _gecmis.first) / _gecmis.first * 100;
    }
    return _kart(
      cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("PORTFÖY GRAFİĞİ", style: _kucukBaslik),
          const Spacer(),
          Text("${yuzde >= 0 ? '+' : ''}${yuzde.toStringAsFixed(2)}%",
              style: TextStyle(color: _pnlRenk(yuzde), fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(_para(bakiye),
            style: const TextStyle(color: Renk.yazi, fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: _gecmis.length < 2
              ? const Center(
                  child: Text("Veri toplanıyor... (panel her 5 dk kaydeder)",
                      style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)))
              : CustomPaint(painter: _CizgiPainter(_gecmis)),
        ),
      ]),
    );
  }

  Widget _metrikGrid(Map<String, dynamic>? v, Map st) {
    final bakiye = _d(v?["bakiye"]);
    final pnl = _d(v?["acik_pnl"]);
    final gunluk = _d(st["gunluk_pnl"]);
    final acikSayi = (v?["acik_sayi"] ?? 0);
    final isabet = _d(st["isabet_yuzde"]);
    final pf = _d(st["profit_factor"]);
    return Column(children: [
      Row(children: [
        Expanded(child: _metrikKart("BAKIYE", _para(bakiye), Icons.account_balance_wallet_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("AÇIK PNL", _para(pnl, isaret: true), Icons.trending_up, renk: _pnlRenk(pnl))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metrikKart("GÜNLÜK KAR", _para(gunluk, isaret: true), Icons.pie_chart_outline, renk: _pnlRenk(gunluk))),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("AÇIK POZİSYON", "$acikSayi / 4", Icons.schedule)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metrikKart("İSABET ORANI", "%${isabet.toStringAsFixed(0)}", Icons.adjust, renk: Renk.altin)),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("PROFIT FACTOR", pf.toStringAsFixed(2), Icons.bar_chart, renk: pf >= 1 ? Renk.teal : Renk.kirmizi)),
      ]),
    ]);
  }

  Widget _metrikKart(String etiket, String deger, IconData ikon, {Color? renk}) {
    return _kart(
      ic: const EdgeInsets.all(14),
      cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(etiket, style: _kucukBaslik)),
          Icon(ikon, color: Renk.yaziSoluk, size: 16),
        ]),
        const SizedBox(height: 10),
        Text(deger, style: TextStyle(color: renk ?? Renk.yazi, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _aiKart() {
    return GestureDetector(
      onTap: () => widget.onSekme?.call(2),
      child: _kart(
        cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.psychology, color: Renk.mavi, size: 18),
            const SizedBox(width: 8),
            const Text("AI PİYASA ANALİZİ",
                style: TextStyle(color: Renk.mavi, fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Renk.yaziSoluk, size: 18),
          ]),
          const SizedBox(height: 14),
          if (_aiYukleniyor)
            Row(children: const [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Renk.mavi)),
              SizedBox(width: 10),
              Text("Hesaplanıyor...", style: TextStyle(color: Renk.yaziSoluk)),
            ])
          else if (_aiOzet == null || _aiOzet!["gostergeler"] == null)
            const Text("Analiz alınamadı (panel/internet?)",
                style: TextStyle(color: Renk.yaziSoluk, fontSize: 12))
          else
            _aiOzetIcerik(),
        ]),
      ),
    );
  }

  Widget _aiOzetIcerik() {
    final coin = (_aiOzet!["coin"] ?? "").toString().replaceAll("USDT", "");
    final trend = (_aiOzet!["trend"] ?? "—").toString();
    final guven = (_aiOzet!["guven"] ?? 0);
    final trendRenk = trend.contains("YUKSEL")
        ? Renk.teal
        : (trend.contains("DUSUS") ? Renk.kirmizi : Renk.altin);
    return Row(children: [
      _Halka(yuzde: (guven is num ? guven.toDouble() : 0) / 100, etiket: "$guven%", boyut: 64),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("$coin · $trend",
              style: TextStyle(color: trendRenk, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text("AI güven skoru — detay için dokun",
              style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
        ]),
      ),
    ]);
  }

  Widget _pozKart(Map<String, dynamic> p) {
    final yon = (p["yon"] ?? "").toString();
    final long = yon == "LONG";
    final sembol = (p["sembol"] ?? "").toString();
    final giris = _d(p["giris"]);
    final mark = _d(p["mark"]);
    final stop = _d(p["stop"]);
    final hedef = _d(p["hedef"]);
    final pnl = _d(p["pnl"]);
    final yuzde = _d(p["yuzde"]);
    final kald = p["kaldirac"];
    double ilerleme = 0;
    if (long && hedef != giris) {
      ilerleme = (mark - giris) / (hedef - giris);
    } else if (!long && giris != hedef) {
      ilerleme = (giris - mark) / (giris - hedef);
    }
    ilerleme = ilerleme.clamp(0.0, 1.0);
    final yonRenk = long ? Renk.teal : Renk.kirmizi;
    return _kart(
      cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: yonRenk.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(yon, style: TextStyle(color: yonRenk, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Text(sembol, style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_para(pnl, isaret: true),
                style: TextStyle(color: _pnlRenk(pnl), fontWeight: FontWeight.w700, fontSize: 15)),
            Text("${yuzde >= 0 ? '+' : ''}${yuzde.toStringAsFixed(2)}%",
                style: TextStyle(color: _pnlRenk(pnl), fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _kv("GİRİŞ", "$giris"),
          _kv("GÜNCEL", "$mark"),
          _kv("TP", "$hedef"),
          _kv("SL", "$stop"),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: ilerleme, minHeight: 6, backgroundColor: Renk.kartAcik, color: yonRenk),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text("${(ilerleme * 100).toStringAsFixed(0)}% hedefe",
              style: const TextStyle(color: Renk.yaziSoluk, fontSize: 11)),
          const Spacer(),
          if (kald != null && kald != 0)
            Text("${kald}x", style: const TextStyle(color: Renk.altin, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _kv(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(color: Renk.yazi, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ============================================================
//  GRAFIK EKRANI - mum grafigi (kendi cizici) + destek/direnc
// ============================================================
class GrafikEkrani extends StatefulWidget {
  const GrafikEkrani({super.key});
  @override
  State<GrafikEkrani> createState() => _GrafikEkraniState();
}

class _GrafikEkraniState extends State<GrafikEkrani> {
  final _coinler = const ["TON", "ETH", "SOL", "XRP", "DOGE", "LINK"];
  String _coin = "ETH";
  bool _yukleniyor = true;
  List<Map<String, dynamic>> _mumlar = [];
  List<Map<String, dynamic>> _seviyeler = [];

  @override
  void initState() {
    super.initState();
    _cek();
  }

  Future<void> _cek() async {
    setState(() => _yukleniyor = true);
    final v = await _panel("/mum?coin=${_coin}USDT&aralik=15m");
    if (!mounted) return;
    if (v is Map) {
      _mumlar = ((v["mumlar"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      _seviyeler = ((v["seviyeler"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _mumlar = [];
      _seviyeler = [];
    }
    setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("CANLI GRAFİK", style: _baslikStil),
      const SizedBox(height: 12),
      _coinSecici(_coinler, _coin, (c) {
        setState(() => _coin = c);
        _cek();
      }),
      const SizedBox(height: 16),
      _kart(
        cocuk: SizedBox(
          height: 340,
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator(color: Renk.teal))
              : _mumlar.length < 2
                  ? const Center(child: Text("Veri alınamadı", style: TextStyle(color: Renk.yaziSoluk)))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text("${_coin}USDT",
                            style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(width: 8),
                        const Text("15dk", style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
                        const Spacer(),
                        Text(_d(_mumlar.last["c"]).toString(),
                            style: const TextStyle(color: Renk.teal, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, double.infinity),
                          painter: _MumPainter(_mumlar, _seviyeler),
                        ),
                      ),
                    ]),
        ),
      ),
      const SizedBox(height: 12),
      const Text("Sarı kesik çizgiler: canlı destek/direnç (By Murat)",
          style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
      const SizedBox(height: 24),
    ]);
  }
}

// ============================================================
//  AI ANALIZ EKRANI - gercek gostergeler + guven + bot sinyali
// ============================================================
class AIAnalizEkrani extends StatefulWidget {
  const AIAnalizEkrani({super.key});
  @override
  State<AIAnalizEkrani> createState() => _AIAnalizEkraniState();
}

class _AIAnalizEkraniState extends State<AIAnalizEkrani> {
  final _coinler = const ["TON", "ETH", "SOL", "XRP", "DOGE", "LINK"];
  String _coin = "ETH";
  bool _yukleniyor = true;
  Map<String, dynamic>? _veri;

  @override
  void initState() {
    super.initState();
    _cek();
  }

  Future<void> _cek() async {
    setState(() => _yukleniyor = true);
    final v = await _panel("/analiz?coin=${_coin}USDT");
    if (!mounted) return;
    setState(() {
      _veri = (v is Map) ? Map<String, dynamic>.from(v) : null;
      _yukleniyor = false;
    });
  }

  Color _sinyalRenk(String s) {
    if (s == "AL" || s.contains("SATIM") || s == "GUCLU TREND" || s == "GUCLU") return Renk.teal;
    if (s == "SAT" || s.contains("ALIM")) return Renk.kirmizi;
    return Renk.yaziSoluk;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("AI PİYASA ANALİZİ", style: _baslikStil),
      const SizedBox(height: 12),
      _coinSecici(_coinler, _coin, (c) {
        setState(() => _coin = c);
        _cek();
      }),
      const SizedBox(height: 16),
      if (_yukleniyor)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Renk.mavi)))
      else if (_veri == null)
        _bosKutu("Analiz alınamadı (panel/internet?)")
      else
        ..._icerik(),
      const SizedBox(height: 24),
    ]);
  }

  List<Widget> _icerik() {
    final trend = (_veri!["trend"] ?? "—").toString();
    final guven = (_veri!["guven"] ?? 0);
    final gost = (_veri!["gostergeler"] as List?) ?? [];
    final bot = (_veri!["bot_sinyali"] as Map?) ?? {};
    final trendRenk = trend.contains("YUKSEL")
        ? Renk.teal
        : (trend.contains("DUSUS") ? Renk.kirmizi : Renk.altin);
    return [
      _kart(
        cocuk: Row(children: [
          _Halka(yuzde: (guven is num ? guven.toDouble() : 0) / 100, etiket: "$guven%", boyut: 92),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${_coin}USDT",
                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(_d(_veri!["fiyat"]).toString(), style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: trendRenk.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(trend, style: TextStyle(color: trendRenk, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      const Text("GÖSTERGELER", style: _kucukBaslik),
      const SizedBox(height: 8),
      ...gost.map((g) {
        final m = Map<String, dynamic>.from(g);
        final s = (m["sinyal"] ?? "").toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _kart(
            ic: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            cocuk: Row(children: [
              Text(m["ad"].toString(), style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(m["deger"].toString(), style: const TextStyle(color: Renk.yazi, fontSize: 13)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _sinyalRenk(s).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(s, style: TextStyle(color: _sinyalRenk(s), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 16),
      const Text("BOTUN SİNYALİ (destek/direnç)", style: _kucukBaslik),
      const SizedBox(height: 8),
      _kart(
        cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.smart_toy_outlined, color: Renk.mavi, size: 18),
            const SizedBox(width: 8),
            Text(bot["yon"]?.toString() ?? "BEKLE",
                style: TextStyle(
                    color: bot["yon"] != null ? Renk.teal : Renk.yaziSoluk, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (bot["rr"] != null)
              Text("RR ${bot["rr"]}", style: const TextStyle(color: Renk.altin, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(bot["sebep"]?.toString() ?? "-", style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
        ]),
      ),
    ];
  }
}

// ============================================================
//  MESAJ EKRANI - asistanla sohbet (/sor)
// ============================================================
class _Mesaj {
  final String metin;
  final bool benim;
  _Mesaj(this.metin, this.benim);
}

class MesajEkrani extends StatefulWidget {
  const MesajEkrani({super.key});
  @override
  State<MesajEkrani> createState() => _MesajEkraniState();
}

class _MesajEkraniState extends State<MesajEkrani> {
  final _girdi = TextEditingController();
  final _kaydir = ScrollController();
  final List<_Mesaj> _mesajlar = [];
  bool _bekliyor = false;

  @override
  void initState() {
    super.initState();
    _mesajlar.add(_Mesaj(
        "Selam! 🦅 Akıncı asistanındayım. Durum, bakiye, pozisyonlar, \"ETH neden açıldı\", \"RR ne demek\" gibi sorabilirsin.",
        false));
  }

  @override
  void dispose() {
    _girdi.dispose();
    _kaydir.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final s = _girdi.text.trim();
    if (s.isEmpty || _bekliyor) return;
    setState(() {
      _mesajlar.add(_Mesaj(s, true));
      _bekliyor = true;
      _girdi.clear();
    });
    _altaKay();
    final v = await _panel("/sor?soru=${Uri.encodeComponent(s)}");
    String cevap = "Asistana ulaşılamadı (panel açık mı?)";
    if (v is Map && v["cevap"] != null) cevap = v["cevap"].toString();
    if (!mounted) return;
    setState(() {
      _mesajlar.add(_Mesaj(cevap, false));
      _bekliyor = false;
    });
    _altaKay();
  }

  void _altaKay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kaydir.hasClients) {
        _kaydir.animateTo(_kaydir.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text("ASİSTAN", style: _baslikStil),
          const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Renk.teal, shape: BoxShape.circle)),
          const Spacer(),
          const Text("kural-bazlı", style: TextStyle(color: Renk.yaziSoluk, fontSize: 11)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: _kaydir,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _mesajlar.length + (_bekliyor ? 1 : 0),
          itemBuilder: (c, i) {
            if (i == _mesajlar.length) return _balon(_Mesaj("yazıyor...", false));
            return _balon(_mesajlar[i]);
          },
        ),
      ),
      _girisAlani(),
    ]);
  }

  Widget _balon(_Mesaj m) {
    return Align(
      alignment: m.benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.benim ? Renk.teal.withOpacity(0.15) : Renk.kart,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.benim ? Renk.teal.withOpacity(0.4) : Renk.cizgi),
        ),
        child: Text(m.metin, style: const TextStyle(color: Renk.yazi, fontSize: 14, height: 1.35)),
      ),
    );
  }

  Widget _girisAlani() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(color: Renk.kart, border: Border(top: BorderSide(color: Renk.cizgi))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _girdi,
            style: const TextStyle(color: Renk.yazi),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _gonder(),
            decoration: InputDecoration(
              hintText: "Bir şey sor...",
              hintStyle: const TextStyle(color: Renk.yaziSoluk),
              filled: true,
              fillColor: Renk.arkaplan,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _gonder,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: Renk.teal, shape: BoxShape.circle),
            child: Icon(_bekliyor ? Icons.hourglass_top : Icons.send, color: Renk.arkaplan, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
//  CIZICILER (CustomPainter) - portfoy cizgisi, mum, guven halkasi
// ============================================================
class _CizgiPainter extends CustomPainter {
  final List<double> veri;
  _CizgiPainter(this.veri);
  @override
  void paint(Canvas canvas, Size size) {
    if (veri.length < 2) return;
    final mn = veri.reduce(math.min);
    final mx = veri.reduce(math.max);
    final aralik = (mx - mn).abs() < 1e-9 ? 1.0 : (mx - mn);
    final dx = size.width / (veri.length - 1);
    final yol = Path();
    final dolu = Path();
    for (int i = 0; i < veri.length; i++) {
      final x = dx * i;
      final y = size.height - ((veri[i] - mn) / aralik) * size.height;
      if (i == 0) {
        yol.moveTo(x, y);
        dolu.moveTo(x, size.height);
        dolu.lineTo(x, y);
      } else {
        yol.lineTo(x, y);
        dolu.lineTo(x, y);
      }
    }
    dolu.lineTo(size.width, size.height);
    dolu.close();
    final renk = veri.last >= veri.first ? Renk.teal : Renk.kirmizi;
    canvas.drawPath(
      dolu,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [renk.withOpacity(0.25), renk.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      yol,
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CizgiPainter o) => o.veri != veri;
}

class _MumPainter extends CustomPainter {
  final List<Map<String, dynamic>> mumlar;
  final List<Map<String, dynamic>> seviyeler;
  _MumPainter(this.mumlar, this.seviyeler);
  @override
  void paint(Canvas canvas, Size size) {
    if (mumlar.isEmpty) return;
    double mn = double.infinity, mx = -double.infinity;
    for (final m in mumlar) {
      final h = _d(m["h"]);
      final l = _d(m["l"]);
      if (h > mx) mx = h;
      if (l < mn) mn = l;
    }
    final aralik = (mx - mn).abs() < 1e-9 ? 1.0 : (mx - mn);
    double y(double f) => size.height - ((f - mn) / aralik) * size.height;
    final n = mumlar.length;
    final gen = size.width / n;
    final govdeW = gen * 0.6;
    for (int i = 0; i < n; i++) {
      final m = mumlar[i];
      final o = _d(m["o"]);
      final c = _d(m["c"]);
      final h = _d(m["h"]);
      final l = _d(m["l"]);
      final x = gen * i + gen / 2;
      final renk = c >= o ? Renk.teal : Renk.kirmizi;
      canvas.drawLine(Offset(x, y(h)), Offset(x, y(l)), Paint()..color = renk..strokeWidth = 1);
      final ust = y(math.max(o, c));
      var alt = y(math.min(o, c));
      if (alt < ust + 1) alt = ust + 1;
      canvas.drawRect(Rect.fromLTRB(x - govdeW / 2, ust, x + govdeW / 2, alt), Paint()..color = renk);
    }
    for (final s in seviyeler) {
      final f = _d(s["fiyat"]);
      if (f < mn || f > mx) continue;
      final yy = y(f);
      final guc = (s["guc"] is num) ? (s["guc"] as num).toInt() : 0;
      final cizgi = Paint()
        ..color = Renk.altin.withOpacity(0.55)
        ..strokeWidth = guc >= 3 ? 1.5 : 0.8;
      double sx = 0;
      while (sx < size.width) {
        canvas.drawLine(Offset(sx, yy), Offset(sx + 6, yy), cizgi);
        sx += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MumPainter o) => true;
}

class _Halka extends StatelessWidget {
  final double yuzde;
  final String etiket;
  final double boyut;
  const _Halka({required this.yuzde, required this.etiket, this.boyut = 80});
  @override
  Widget build(BuildContext context) {
    final renk = yuzde >= 0.66 ? Renk.teal : (yuzde >= 0.4 ? Renk.altin : Renk.kirmizi);
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(boyut, boyut), painter: _HalkaPainter(yuzde.clamp(0.0, 1.0), renk)),
        Text(etiket, style: TextStyle(color: renk, fontWeight: FontWeight.w700, fontSize: boyut * 0.22)),
      ]),
    );
  }
}

class _HalkaPainter extends CustomPainter {
  final double yuzde;
  final Color renk;
  _HalkaPainter(this.yuzde, this.renk);
  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final yari = size.width / 2 - 4;
    canvas.drawCircle(
        merkez,
        yari,
        Paint()
          ..color = Renk.kartAcik
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: merkez, radius: yari),
        -math.pi / 2,
        2 * math.pi * yuzde,
        false,
        Paint()
          ..color = renk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _HalkaPainter o) => o.yuzde != yuzde || o.renk != renk;
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
