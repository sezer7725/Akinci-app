// ============================================================
//  AKINCI KOMUTA MERKEZI - main.dart  (v2 - tam yeniden yazim)
//  Renk: turkuaz palet | Nav: 5 sekme + FAB analiz
//  Yeni: PiyasaEkrani, GecmisEkrani, AyarlarSayfasi
//  Gelismis: bildirim merkezi, pozisyon KAPAT, komuta seridi
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

// ---- Renk paleti (turkuaz) ----
class Renk {
  static const arkaplan  = Color(0xFF081316);
  static const kart      = Color(0xFF0F2227);
  static const kartAcik  = Color(0xFF143036);
  static const teal      = Color(0xFF2FE9CE);
  static const mavi      = Color(0xFF35C8E8);
  static const kirmizi   = Color(0xFFFF6B7C);
  static const altin     = Color(0xFFF0C46B);
  static const yazi      = Color(0xFFEAF6F4);
  static const yaziSoluk = Color(0xFF93C2C4);
  static const cizgi     = Color(0xFF1B3A40);
}

const String kKullanici = "AkinciV1";
const String kSifre     = "akinci77";
const String kPanelUrl  = "http://127.0.0.1:8080";
String gPanelUrl = kPanelUrl;

// Rejim -> GUC/STOP haritasi (bot ile ayni)
const Map<String, List<num>> kRejimAyar = {
  "boga": [90, 2.0], "ayi": [70, 2.2],
  "yatay": [70, 2.0], "belirsiz": [70, 2.0],
};
Color _rejimRenk(String r) =>
    r == "boga" ? Renk.teal : (r == "ayi" ? Renk.kirmizi : Renk.altin);
String _rejimAd(String r) =>
    r == "boga" ? "BOĞA" : (r == "ayi" ? "AYI" : (r == "yatay" ? "YATAY" : "BELİRSİZ"));

// FAB'tan Analiz ekranina coin gondermek icin
final ValueNotifier<String> gAnalizCoin = ValueNotifier<String>("ETH");

// ============================================================
//  DURUM SERVISI
// ============================================================
class DurumServisi extends ChangeNotifier {
  DurumServisi._();
  static final DurumServisi instance = DurumServisi._();

  Map<String, dynamic>? _veri;
  DateTime? _sonBasari;
  int _ardArdaHata = 0;
  bool _ilkYukleme = true;
  Timer? _zamanlayici;
  Timer? _olayZamanlayici;
  bool _calisiyor = false;

  // Bildirim merkezi
  List<Map<String, dynamic>> olaylar = [];
  int okunmamis = 0;
  int _sonGorulenTs = 0;

  Map<String, dynamic>? get veri => _veri;
  bool get ilkYukleme => _ilkYukleme;
  bool get bagliMi {
    if (_veri == null || _sonBasari == null) return false;
    return _ardArdaHata < 3 &&
        DateTime.now().difference(_sonBasari!).inSeconds < 20;
  }
  int get saniyeOnce {
    if (_sonBasari == null) return -1;
    return DateTime.now().difference(_sonBasari!).inSeconds;
  }

  void basla() {
    if (_calisiyor) return;
    _calisiyor = true;
    _cek();
    _zamanlayici = Timer.periodic(const Duration(seconds: 5), (_) => _cek());
    _olaylarCek();
    _olayZamanlayici =
        Timer.periodic(const Duration(seconds: 20), (_) => _olaylarCek());
    SharedPreferences.getInstance().then((p) {
      _sonGorulenTs = p.getInt('son_olay_ts') ?? 0;
    });
  }

  void durdur() {
    _olayZamanlayici?.cancel(); _olayZamanlayici = null;
    _zamanlayici?.cancel(); _zamanlayici = null;
    _calisiyor = false;
  }

  Future<void> elleYenile() async => _cek();

  Future<void> _cek() async {
    try {
      final r = await http
          .get(Uri.parse("$gPanelUrl/durum"))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        _veri = json.decode(utf8.decode(r.bodyBytes));
        _sonBasari = DateTime.now();
        _ardArdaHata = 0;
        _ilkYukleme = false;
        notifyListeners();
        return;
      }
    } catch (_) {}
    _ardArdaHata++;
    _ilkYukleme = false;
    notifyListeners();
  }

  Future<void> _olaylarCek() async {
    try {
      final r = await http
          .get(Uri.parse("$gPanelUrl/bildirimler"))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final v = json.decode(utf8.decode(r.bodyBytes));
        if (v is Map && v["olaylar"] is List) {
          olaylar = (v["olaylar"] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          okunmamis =
              olaylar.where((o) => (o["ts"] ?? 0) > _sonGorulenTs).length;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> olaylariGordum() async {
    if (olaylar.isNotEmpty) {
      _sonGorulenTs = (olaylar.first["ts"] ?? 0) as int;
      okunmamis = 0;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setInt('son_olay_ts', _sonGorulenTs);
      } catch (_) {}
      notifyListeners();
    }
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
          primary: Renk.teal, surface: Renk.kart),
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

  Future<void> _kayitliBilgiYukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      gPanelUrl = p.getString('panel_url') ?? kPanelUrl;
      final hatirla = p.getBool('beni_hatirla') ?? false;
      if (hatirla) {
        final k = p.getString('kullanici') ?? '';
        final s = p.getString('sifre') ?? '';
        if (k == kKullanici && s == kSifre && mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const AnaKabuk()));
          return;
        }
      }
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
    await Future.delayed(const Duration(milliseconds: 300));
    final k = _kullaniciCtrl.text.trim();
    final s = _sifreCtrl.text;
    if (k == kKullanici && s == kSifre) {
      HapticFeedback.mediumImpact();
      try {
        final p = await SharedPreferences.getInstance();
        await p.setBool('beni_hatirla', _beniHatirla);
        if (_beniHatirla) {
          await p.setString('kullanici', k);
          await p.setString('sifre', s);
        } else {
          await p.remove('sifre');
          await p.setString('kullanici', k);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AnaKabuk()));
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _hata = "Kullanici adi veya sifre yanlis"; _yukleniyor = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: KodYagmuru()),
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
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(
                          color: Renk.teal.withOpacity(0.25),
                          blurRadius: 40, spreadRadius: 4)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text("AKINCI",
                      style: TextStyle(color: Renk.yazi, fontSize: 34,
                          fontWeight: FontWeight.w700, letterSpacing: 8)),
                  const SizedBox(height: 6),
                  const Text("KOMUTA MERKEZI",
                      style: TextStyle(color: Renk.yaziSoluk, fontSize: 13,
                          letterSpacing: 5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 44),
                  _girisAlani(_kullaniciCtrl, "Kullanici adi",
                      Icons.person_outline, false),
                  const SizedBox(height: 14),
                  _girisAlani(_sifreCtrl, "Sifre", Icons.lock_outline, true),
                  const SizedBox(height: 6),
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
                              color: _beniHatirla
                                  ? Renk.teal
                                  : Renk.yaziSoluk.withOpacity(0.5),
                              width: 1.5),
                        ),
                        child: _beniHatirla
                            ? const Icon(Icons.check, color: Renk.arkaplan, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Text("Beni hatirla",
                          style: TextStyle(color: Renk.yaziSoluk, fontSize: 13,
                              fontWeight: FontWeight.w500)),
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
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _yukleniyor ? null : _girisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Renk.teal,
                        foregroundColor: Renk.arkaplan,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _yukleniyor
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Renk.arkaplan))
                          : const Text("GIRIS YAP",
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700, letterSpacing: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: Renk.teal, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text("guvenli baglanti · v2.0",
                        style: TextStyle(color: Renk.yaziSoluk, fontSize: 12)),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _girisAlani(TextEditingController ctrl, String ipucu,
      IconData ikon, bool sifre) {
    return TextField(
      controller: ctrl,
      obscureText: sifre,
      style: const TextStyle(color: Renk.yazi, fontSize: 15),
      onSubmitted: (_) => _girisYap(),
      decoration: InputDecoration(
        hintText: ipucu,
        hintStyle: const TextStyle(color: Renk.yaziSoluk),
        prefixIcon: Icon(ikon, color: Renk.yaziSoluk, size: 20),
        filled: true,
        fillColor: Renk.kart,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Renk.cizgi)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Renk.teal)),
        border: InputBorder.none,
      ),
    );
  }
}

// ============================================================
//  ORTAK YARDIMCILAR
// ============================================================
Future<dynamic> _panel(String yol) async {
  try {
    final r = await http
        .get(Uri.parse("$gPanelUrl$yol"))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) return json.decode(utf8.decode(r.bodyBytes));
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

Widget _kart({required Widget cocuk, EdgeInsets? ic}) => Container(
      padding: ic ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Renk.cizgi),
      ),
      child: cocuk,
    );

Widget _bosKutu(String mesaj) => _kart(
    cocuk: Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(mesaj, style: const TextStyle(color: Renk.yaziSoluk)))));

Widget _coinSecici(
    List<String> coinler, String secili, void Function(String) sec) {
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
//  ANA KABUK - 5 sekme + FAB
// ============================================================
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});
  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk>
    with SingleTickerProviderStateMixin {
  int _sekme = 0;
  late final AnimationController _pulse;
  final _servis = DurumServisi.instance;

  @override
  void initState() {
    super.initState();
    DurumServisi.instance.basla();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _git(int i) => setState(() => _sekme = i);

  void _bildirimAc() {
    _servis.olaylariGordum();
    showModalBottomSheet(
      context: context,
      backgroundColor: Renk.kart,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 42, height: 4,
              decoration: BoxDecoration(color: Renk.cizgi,
                  borderRadius: BorderRadius.circular(4))),
          const Padding(padding: EdgeInsets.all(14),
              child: Text("BİLDİRİMLER", style: _baslikStil)),
          Expanded(
            child: _servis.olaylar.isEmpty
                ? const Center(
                    child: Text("Henüz olay yok",
                        style: TextStyle(color: Renk.yaziSoluk)))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _servis.olaylar.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Renk.cizgi, height: 1),
                    itemBuilder: (_, i) {
                      final o = _servis.olaylar[i];
                      final t = DateTime.fromMillisecondsSinceEpoch(
                          ((o["ts"] ?? 0) as int) * 1000);
                      final saat =
                          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(o["metin"]?.toString() ?? "",
                                      style: const TextStyle(
                                          color: Renk.yazi,
                                          fontSize: 12.5,
                                          height: 1.4))),
                              const SizedBox(width: 10),
                              Text(saat,
                                  style: const TextStyle(
                                      color: Renk.yaziSoluk, fontSize: 11)),
                            ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              width: 42, height: 42,
              child: Image.asset('logo.png', fit: BoxFit.cover)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text("AKINCI",
              style: TextStyle(color: Renk.yazi, fontSize: 18,
                  fontWeight: FontWeight.w700, letterSpacing: 2)),
          Text("KOMUTA MERKEZİ",
              style: TextStyle(color: Renk.yaziSoluk, fontSize: 10, letterSpacing: 3)),
        ]),
        const Spacer(),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final aktif = (_servis.veri?["bot_aktif"] == true);
            final renk = aktif ? Renk.teal : Renk.kirmizi;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: renk.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: renk.withOpacity(0.45)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: aktif ? (0.35 + 0.65 * _pulse.value) : 1,
                  child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: renk, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: renk.withOpacity(0.7), blurRadius: 6)])),
                ),
                const SizedBox(width: 6),
                Text(aktif ? "LIVE" : "DURDU",
                    style: TextStyle(color: renk, fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
            );
          },
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _bildirimAc,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Renk.kartAcik,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Renk.cizgi)),
              child: const Icon(Icons.notifications_none,
                  color: Renk.yaziSoluk, size: 19),
            ),
            if (_servis.okunmamis > 0)
              Positioned(
                right: -3, top: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Renk.kirmizi, shape: BoxShape.circle),
                  child: Text("${_servis.okunmamis}",
                      style: const TextStyle(color: Colors.white, fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AyarlarSayfasi())),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Renk.kartAcik,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Renk.cizgi)),
            child: const Icon(Icons.settings_outlined,
                color: Renk.yaziSoluk, size: 19),
          ),
        ),
      ]),
    );
  }

  Widget _serit() {
    final v = _servis.veri;
    final rejim = (v?["rejim"] ?? "belirsiz").toString();
    final ayarlar = kRejimAyar[rejim] ?? kRejimAyar["belirsiz"]!;
    final fund = v?["funding_btc"];
    Widget chip(Widget icerik) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
              color: Renk.kart, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Renk.cizgi)),
          child: icerik,
        );
    Text t(String a, {Color? c, FontWeight? w}) => Text(a,
        style: TextStyle(color: c ?? Renk.yaziSoluk, fontSize: 11,
            fontWeight: w ?? FontWeight.w600, letterSpacing: 0.5));
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    color: _rejimRenk(rejim), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            t("REJİM "), t(_rejimAd(rejim), c: Renk.yazi, w: FontWeight.w800),
          ])),
          chip(Row(mainAxisSize: MainAxisSize.min, children: [
            t("GUC "), t("${ayarlar[0]}", c: Renk.yazi, w: FontWeight.w800),
          ])),
          chip(Row(mainAxisSize: MainAxisSize.min, children: [
            t("STOP "), t("×${ayarlar[1]}", c: Renk.yazi, w: FontWeight.w800),
          ])),
          if (fund != null)
            chip(Row(mainAxisSize: MainAxisSize.min, children: [
              t("FUNDING "), t("%$fund", c: Renk.yazi, w: FontWeight.w800),
            ])),
          chip(Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    color: _servis.bagliMi ? Renk.teal : Renk.kirmizi,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            t("VERİ "),
            t(_servis.saniyeOnce < 0 ? "-" : "${_servis.saniyeOnce}sn",
                c: Renk.yazi, w: FontWeight.w800),
          ])),
        ],
      ),
    );
  }

  Widget _offlineBar() {
    if (_servis.bagliMi || _servis.ilkYukleme) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Renk.kirmizi.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Text("PANEL BAĞLANTISI KOPTU — YENİDEN DENENİYOR…",
          textAlign: TextAlign.center,
          style: TextStyle(color: Renk.kirmizi, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }

  Widget _navButon(int i, IconData ikon, String ad) {
    final aktif = _sekme == i;
    return Expanded(
      child: InkWell(
        onTap: () => _git(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, size: 22, color: aktif ? Renk.teal : Renk.yaziSoluk),
            const SizedBox(height: 3),
            Text(ad, style: TextStyle(
                color: aktif ? Renk.teal : Renk.yaziSoluk,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekranlar = [
      DashboardEkrani(onSekme: _git),
      PiyasaEkrani(onAnalize: (coin) { gAnalizCoin.value = coin; _git(2); }),
      const AIAnalizEkrani(),
      const MesajEkrani(),
      const GecmisEkrani(),
    ];
    return AnimatedBuilder(
      animation: _servis,
      builder: (context, _) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: KodYagmuru()),
          Positioned.fill(
              child: Container(color: Renk.arkaplan.withOpacity(0.88))),
          SafeArea(
            bottom: false,
            child: Column(children: [
              _header(),
              _serit(),
              _offlineBar(),
              const SizedBox(height: 4),
              Expanded(
                  child: IndexedStack(index: _sekme, children: ekranlar)),
            ]),
          ),
        ]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
              color: Renk.kart,
              border: Border(top: BorderSide(color: Renk.cizgi))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(children: [
                _navButon(0, Icons.home_outlined, "ANA SAYFA"),
                _navButon(1, Icons.bar_chart_outlined, "PİYASA"),
                SizedBox(
                  width: 72,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _git(2),
                      child: Container(
                        width: 54, height: 54,
                        transform: Matrix4.translationValues(0, -16, 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF35F0D4), Color(0xFF0EC9AC)]),
                          border: Border.all(color: Renk.arkaplan, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Renk.teal
                                    .withOpacity(_sekme == 2 ? 0.65 : 0.35),
                                blurRadius: 18, spreadRadius: 1),
                          ],
                        ),
                        child: const Icon(Icons.radar,
                            color: Color(0xFF06251F), size: 26),
                      ),
                    ),
                  ),
                ),
                _navButon(3, Icons.forum_outlined, "ASİSTAN"),
                _navButon(4, Icons.history, "GEÇMİŞ"),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  DASHBOARD (ANA SAYFA)
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

  Future<void> _kapat(String sembol) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Renk.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Pozisyonu kapat",
            style: TextStyle(color: Renk.yazi, fontSize: 17)),
        content: Text(
            "$sembol piyasa fiyatından hemen kapatılacak. Bu işlem geri alınamaz.",
            style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("VAZGEÇ",
                  style: TextStyle(color: Renk.yaziSoluk))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("EVET, KAPAT",
                  style: TextStyle(color: Renk.kirmizi, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (onay != true) return;
    HapticFeedback.mediumImpact();
    final r = await _panel("/kapat?sembol=$sembol");
    if (!mounted) return;
    final mesaj = (r is Map)
        ? (r["mesaj"] ?? r["hata"] ?? "cevap alınamadı").toString()
        : "Panele ulaşılamadı";
    final ok = (r is Map) && r["ok"] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? Renk.kart : Renk.kirmizi.withOpacity(0.9),
      content: Text(mesaj, style: const TextStyle(color: Renk.yazi)),
    ));
    if (ok) Future.delayed(const Duration(seconds: 4), () => _servis.elleYenile());
  }

  void _pozDetay(Map<String, dynamic> p) {
    final long = p["yon"] == "LONG";
    showModalBottomSheet(
      context: context,
      backgroundColor: Renk.kart,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4,
              decoration: BoxDecoration(color: Renk.cizgi,
                  borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Row(children: [
            Text("${p["sembol"]}", style: _baslikStil),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: (long ? Renk.teal : Renk.kirmizi).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(p["yon"].toString(),
                  style: TextStyle(
                      color: long ? Renk.teal : Renk.kirmizi,
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Text(_para(_d(p["pnl"]), isaret: true),
                style: TextStyle(color: _pnlRenk(_d(p["pnl"])),
                    fontWeight: FontWeight.w800, fontSize: 17)),
          ]),
          const SizedBox(height: 14),
          _detaySatir("Giriş → Mark", "${p["giris"]} → ${p["mark"]}"),
          _detaySatir("Hedef", "${p["hedef"]}"),
          _detaySatir("Stop", "${p["stop"]}"),
          _detaySatir("Kaldıraç", "${p["kaldirac"]}×"),
          _detaySatir("Senaryo", "${p["senaryo"]}"),
          _detaySatir("Kâr planı", "Break-even → Trailing"),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Renk.cizgi),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text("TAMAM",
                  style: TextStyle(color: Renk.yazi)),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _kapat(p["sembol"].toString());
              },
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Renk.kirmizi.withOpacity(0.5)),
                  backgroundColor: Renk.kirmizi.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text("KAPAT",
                  style: TextStyle(color: Renk.kirmizi,
                      fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _detaySatir(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(a, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
          const Spacer(),
          Flexible(child: Text(b, textAlign: TextAlign.right,
              style: const TextStyle(color: Renk.yazi, fontSize: 13,
                  fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _pozKart(Map<String, dynamic> p) {
    final long = p["yon"] == "LONG";
    final renk = long ? Renk.teal : Renk.kirmizi;
    final giris = _d(p["giris"]), mark = _d(p["mark"]), hedef = _d(p["hedef"]);
    double ilerleme = 0;
    if (hedef != giris) {
      ilerleme = ((mark - giris) / (hedef - giris)).clamp(0.0, 1.0);
    }
    return GestureDetector(
      onTap: () => _pozDetay(p),
      child: Container(
        decoration: BoxDecoration(
            color: Renk.kart,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Renk.cizgi)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              width: 3.5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: renk,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(
                      color: renk.withOpacity(0.6), blurRadius: 8)])),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(p["sembol"].toString(),
                      style: const TextStyle(color: Renk.yazi,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: renk.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(p["yon"].toString(),
                        style: TextStyle(color: renk, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text("${p["kaldirac"]}×",
                      style: const TextStyle(
                          color: Renk.yaziSoluk, fontSize: 11)),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_para(_d(p["pnl"]), isaret: true),
                        style: TextStyle(
                            color: _pnlRenk(_d(p["pnl"])),
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text("%${_d(p["yuzde"]).toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Renk.yaziSoluk, fontSize: 11)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _pozAlan("GİRİŞ", "${p["giris"]}"),
                  _pozAlan("MARK", "${p["mark"]}"),
                  _pozAlan("HEDEF", "${p["hedef"]}"),
                  _pozAlan("STOP", "${p["stop"]}"),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ilerleme, minHeight: 6,
                        backgroundColor: Renk.cizgi.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation(renk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("HEDEF %${(ilerleme * 100).toStringAsFixed(0)}",
                      style: const TextStyle(color: Renk.yaziSoluk,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _kapat(p["sembol"].toString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Renk.kirmizi.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Renk.kirmizi.withOpacity(0.4)),
                      ),
                      child: const Text("KAPAT",
                          style: TextStyle(color: Renk.kirmizi,
                              fontSize: 10.5, fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pozAlan(String a, String b) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(b, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Renk.yazi, fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _servis,
      builder: (context, _) {
        final v = _servis.veri;
        final st = (v?["istatistik"] as Map?) ?? {};
        final poz = (v?["acik_pozisyon"] as List?) ?? [];
        return RefreshIndicator(
          onRefresh: _yenile,
          color: Renk.teal, backgroundColor: Renk.kart,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    child: _pozKart(Map<String, dynamic>.from(p)))),
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
          const Text("PORTFÖY", style: _kucukBaslik),
          const Spacer(),
          Text("${yuzde >= 0 ? '+' : ''}${yuzde.toStringAsFixed(2)}%",
              style: TextStyle(color: _pnlRenk(yuzde),
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(_para(bakiye),
            style: const TextStyle(color: Renk.yazi, fontSize: 26,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(
          height: 120, width: double.infinity,
          child: _gecmis.length < 2
              ? const Center(
                  child: Text("Veri toplanıyor...",
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
        Expanded(child: _metrikKart("BAKIYE", _para(bakiye),
            Icons.account_balance_wallet_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("AÇIK PNL", _para(pnl, isaret: true),
            Icons.trending_up, renk: _pnlRenk(pnl))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metrikKart("GÜNLÜK KAR",
            _para(gunluk, isaret: true), Icons.pie_chart_outline,
            renk: _pnlRenk(gunluk))),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("AÇIK POZİSYON", "$acikSayi / 4",
            Icons.schedule)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metrikKart("İSABET ORANI",
            "%${isabet.toStringAsFixed(0)}", Icons.adjust, renk: Renk.altin)),
        const SizedBox(width: 12),
        Expanded(child: _metrikKart("PROFIT FACTOR",
            pf.toStringAsFixed(2), Icons.bar_chart,
            renk: pf >= 1 ? Renk.teal : Renk.kirmizi)),
      ]),
    ]);
  }

  Widget _metrikKart(String etiket, String deger, IconData ikon,
      {Color? renk}) {
    return _kart(
      ic: const EdgeInsets.all(14),
      cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(etiket, style: _kucukBaslik)),
          Icon(ikon, color: Renk.yaziSoluk, size: 16),
        ]),
        const SizedBox(height: 10),
        Text(deger, style: TextStyle(
            color: renk ?? Renk.yazi, fontSize: 20, fontWeight: FontWeight.w700)),
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
                style: TextStyle(color: Renk.mavi, fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Renk.yaziSoluk, size: 18),
          ]),
          const SizedBox(height: 14),
          if (_aiYukleniyor)
            const Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Renk.mavi)),
              SizedBox(width: 10),
              Text("Hesaplanıyor...",
                  style: TextStyle(color: Renk.yaziSoluk)),
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
      _Halka(yuzde: (guven is num ? guven.toDouble() : 0) / 100,
          etiket: "$guven%", boyut: 64),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text("$coin", style: const TextStyle(color: Renk.yazi,
            fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: trendRenk.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7)),
          child: Text(trend, style: TextStyle(
              color: trendRenk, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ])),
    ]);
  }
}

// ============================================================
//  PİYASA EKRANI (YENI)
// ============================================================
class PiyasaEkrani extends StatefulWidget {
  final void Function(String coin)? onAnalize;
  const PiyasaEkrani({super.key, this.onAnalize});
  @override
  State<PiyasaEkrani> createState() => _PiyasaEkraniState();
}

class _PiyasaEkraniState extends State<PiyasaEkrani> {
  final _coinler = const ["TON", "ETH", "SOL", "XRP", "DOGE", "LINK"];
  Map<String, dynamic> _fiyatlar = {};
  bool _yukleniyor = true;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _cek();
    _zamanlayici = Timer.periodic(const Duration(seconds: 20), (_) => _cek());
  }

  @override
  void dispose() { _zamanlayici?.cancel(); super.dispose(); }

  Future<void> _cek() async {
    final v = await _panel("/fiyatlar");
    if (!mounted) return;
    if (v is Map && v["fiyatlar"] is Map) {
      setState(() {
        _fiyatlar = Map<String, dynamic>.from(v["fiyatlar"]);
        _yukleniyor = false;
      });
    } else {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = DurumServisi.instance.veri;
    final rejim = (v?["rejim"] ?? "belirsiz").toString();
    final fund = v?["funding_btc"];
    return RefreshIndicator(
      onRefresh: _cek, color: Renk.teal, backgroundColor: Renk.kart,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text("İZLEME LİSTESİ", style: _baslikStil),
        const SizedBox(height: 10),
        _kart(
          ic: EdgeInsets.zero,
          cocuk: _yukleniyor
              ? const Padding(padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator(color: Renk.teal)))
              : Column(children: [
                  _piyasaSatir("BTC", "BTCUSDT", altBaslik: "rejim referansı"),
                  for (final c in _coinler) _piyasaSatir(c, "${c}USDT"),
                ]),
        ),
        const SizedBox(height: 16),
        Text("PİYASA ÖZETİ", style: _baslikStil),
        const SizedBox(height: 10),
        _kart(
          cocuk: Column(children: [
            _ozetSatir("BTC Rejimi (4h)", _rejimAd(rejim),
                renk: _rejimRenk(rejim)),
            const Divider(color: Renk.cizgi, height: 20),
            _ozetSatir("BTC Funding (8s)",
                fund != null ? "%$fund" : "—"),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _piyasaSatir(String kisa, String sembol, {String? altBaslik}) {
    final veri = _fiyatlar[sembol];
    final fiyat = veri != null ? _d(veri["fiyat"]) : 0.0;
    final degisim = veri != null ? _d(veri["degisim"]) : 0.0;
    final renk = _pnlRenk(degisim);
    return InkWell(
      onTap: kisa == "BTC" ? null : () => widget.onAnalize?.call(kisa),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: Renk.kartAcik,
                shape: BoxShape.circle,
                border: Border.all(color: Renk.cizgi)),
            alignment: Alignment.center,
            child: Text(kisa[0],
                style: const TextStyle(color: Renk.yazi,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sembol, style: const TextStyle(color: Renk.yazi,
                fontWeight: FontWeight.w700, fontSize: 14)),
            if (altBaslik != null)
              Text(altBaslik, style: const TextStyle(
                  color: Renk.yaziSoluk, fontSize: 10.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(veri == null ? "—"
                : (fiyat >= 100
                    ? fiyat.toStringAsFixed(1)
                    : fiyat.toStringAsFixed(4)),
                style: const TextStyle(color: Renk.yazi,
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(veri == null ? ""
                : "${degisim >= 0 ? '+' : ''}${degisim.toStringAsFixed(2)}%",
                style: TextStyle(color: renk, fontWeight: FontWeight.w700,
                    fontSize: 11.5)),
          ]),
          if (kisa != "BTC") ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Renk.yaziSoluk, size: 18),
          ],
        ]),
      ),
    );
  }

  Widget _ozetSatir(String etiket, String deger, {Color? renk}) => Row(children: [
        Text(etiket, style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
        const Spacer(),
        Text(deger, style: TextStyle(color: renk ?? Renk.yazi,
            fontWeight: FontWeight.w700, fontSize: 13.5)),
      ]);
}

// ============================================================
//  AI ANALİZ EKRANI (Grafik + Analiz birleşik)
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
  List<Map<String, dynamic>> _mumlar = [];
  List<Map<String, dynamic>> _seviyeler = [];

  @override
  void initState() {
    super.initState();
    _coin = gAnalizCoin.value;
    gAnalizCoin.addListener(_disaridanCoinDegisti);
    _cek();
  }

  @override
  void dispose() {
    gAnalizCoin.removeListener(_disaridanCoinDegisti);
    super.dispose();
  }

  void _disaridanCoinDegisti() {
    if (gAnalizCoin.value != _coin) {
      setState(() => _coin = gAnalizCoin.value);
      _cek();
    }
  }

  Future<void> _cek() async {
    setState(() => _yukleniyor = true);
    final sonuclar = await Future.wait([
      _panel("/analiz?coin=${_coin}USDT"),
      _panel("/mum?coin=${_coin}USDT&aralik=15m"),
    ]);
    if (!mounted) return;
    setState(() {
      _veri = (sonuclar[0] is Map)
          ? Map<String, dynamic>.from(sonuclar[0]) : null;
      if (sonuclar[1] is Map) {
        _mumlar = ((sonuclar[1]["mumlar"] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e)).toList();
        _seviyeler = ((sonuclar[1]["seviyeler"] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _mumlar = []; _seviyeler = [];
      }
      _yukleniyor = false;
    });
  }

  Color _sinyalRenk(String s) {
    if (s == "AL" || s.contains("SATIM") || s == "GUCLU") return Renk.teal;
    if (s == "SAT" || s.contains("ALIM")) return Renk.kirmizi;
    return Renk.yaziSoluk;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("CANLI ANALİZ", style: _baslikStil),
      const SizedBox(height: 12),
      _coinSecici(_coinler, _coin, (c) {
        setState(() => _coin = c);
        gAnalizCoin.value = c;
        _cek();
      }),
      const SizedBox(height: 16),
      if (_yukleniyor)
        const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Renk.mavi)))
      else if (_veri == null)
        _bosKutu("Analiz alınamadı (panel/internet?)")
      else
        ..._icerik(),
      const SizedBox(height: 24),
    ]);
  }

  List<Widget> _icerik() {
    final v = DurumServisi.instance.veri;
    final rejim = (v?["rejim"] ?? "belirsiz").toString();
    final trend = (_veri!["trend"] ?? "—").toString();
    final guven = (_veri!["guven"] is num)
        ? (_veri!["guven"] as num).toDouble() : 0.0;
    final gost = (_veri!["gostergeler"] as List?) ?? [];
    final bot = (_veri!["bot_sinyali"] as Map?) ?? {};
    final trendRenk = trend.contains("YUKSEL")
        ? Renk.teal
        : (trend.contains("DUSUS") ? Renk.kirmizi : Renk.altin);

    double longYuzde = 50;
    if (trend.contains("YUKSEL")) longYuzde = guven.clamp(0, 100);
    else if (trend.contains("DUSUS")) longYuzde = (100 - guven).clamp(0, 100);
    final shortYuzde = 100 - longYuzde;

    return [
      _kart(
        cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text("${_coin}USDT", style: const TextStyle(color: Renk.yazi,
                fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 10),
            Text(_d(_veri!["fiyat"]).toString(),
                style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: trendRenk.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(trend, style: TextStyle(color: trendRenk,
                  fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Text("LONG %${longYuzde.toStringAsFixed(0)}",
                style: const TextStyle(color: Renk.teal,
                    fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Text("SHORT %${shortYuzde.toStringAsFixed(0)}",
                style: const TextStyle(color: Renk.kirmizi,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                Expanded(flex: longYuzde.round().clamp(1, 99),
                    child: Container(color: Renk.teal)),
                Expanded(flex: shortYuzde.round().clamp(1, 99),
                    child: Container(color: Renk.kirmizi)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Akıncı: ${trend.contains("YUKSEL") ? "1h trend yukarı, terazi LONG'a yatık." : trend.contains("DUSUS") ? "1h trend aşağı, terazi SHORT'a yatık." : "Trend belirsiz."} "
            "BTC ${_rejimAd(rejim).toLowerCase()} rejiminde.",
            style: const TextStyle(color: Renk.yaziSoluk, fontSize: 12, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _kart(
        ic: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        cocuk: SizedBox(
          height: 220,
          child: _mumlar.length < 2
              ? const Center(child: Text("Grafik verisi alınamadı",
                  style: TextStyle(color: Renk.yaziSoluk)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("CANLI GRAFİK · 15DK", style: _kucukBaslik),
                  const SizedBox(height: 8),
                  Expanded(child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: _MumPainter(_mumlar, _seviyeler),
                  )),
                ]),
        ),
      ),
      const SizedBox(height: 16),
      const Text("GÖSTERGELER", style: _kucukBaslik),
      const SizedBox(height: 8),
      _kart(
        ic: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        cocuk: Column(children: [
          _gostergeSatir("BTC Rejimi (4h)", _rejimAd(rejim), _rejimRenk(rejim)),
          ...gost.map((g) {
            final m = Map<String, dynamic>.from(g);
            final s = (m["sinyal"] ?? "").toString();
            return _gostergeSatir("${m["ad"]}  ${m["deger"]}", s, _sinyalRenk(s));
          }),
        ]),
      ),
      const SizedBox(height: 16),
      const Text("BOTUN SİNYALİ", style: _kucukBaslik),
      const SizedBox(height: 8),
      _kart(
        cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.smart_toy_outlined, color: Renk.mavi, size: 18),
            const SizedBox(width: 8),
            Text(bot["yon"]?.toString() ?? "BEKLE",
                style: TextStyle(
                    color: bot["yon"] != null ? Renk.teal : Renk.yaziSoluk,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (bot["rr"] != null)
              Text("RR ${bot["rr"]}",
                  style: const TextStyle(color: Renk.altin, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(bot["sebep"]?.toString() ?? "-",
              style: const TextStyle(color: Renk.yaziSoluk, fontSize: 13)),
        ]),
      ),
    ];
  }

  Widget _gostergeSatir(String ad, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Renk.cizgi, width: 0.7))),
      child: Row(children: [
        Expanded(child: Text(ad, style: const TextStyle(
            color: Renk.yaziSoluk, fontSize: 12.5, fontWeight: FontWeight.w600))),
        Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        Text(deger, style: TextStyle(color: renk, fontSize: 11.5,
            fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ============================================================
//  MESAJ EKRANI (ASISTAN)
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
        "Selam! Akıncı asistanındayım. Durum, bakiye, pozisyonlar veya "
        "'ETH neden açıldı', 'RR ne demek' gibi sorabilirsin. "
        "'ETH kapat' yazarsan pozisyonu kapatırım.",
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
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
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: Renk.teal, shape: BoxShape.circle)),
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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.benim ? Renk.teal.withOpacity(0.15) : Renk.kart,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: m.benim ? Renk.teal.withOpacity(0.4) : Renk.cizgi),
        ),
        child: Text(m.metin,
            style: const TextStyle(color: Renk.yazi, fontSize: 14, height: 1.35)),
      ),
    );
  }

  Widget _girisAlani() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(color: Renk.kart,
          border: Border(top: BorderSide(color: Renk.cizgi))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _girdi,
            style: const TextStyle(color: Renk.yazi),
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _gonder(),
            decoration: InputDecoration(
              hintText: "Bir şey sor...",
              hintStyle: const TextStyle(color: Renk.yaziSoluk),
              filled: true, fillColor: Renk.arkaplan,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _gonder,
          child: Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(
                color: Renk.teal, shape: BoxShape.circle),
            child: Icon(_bekliyor ? Icons.hourglass_top : Icons.send,
                color: Renk.arkaplan, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
//  GEÇMİŞ EKRANI (YENI)
// ============================================================
class GecmisEkrani extends StatefulWidget {
  const GecmisEkrani({super.key});
  @override
  State<GecmisEkrani> createState() => _GecmisEkraniState();
}

class _GecmisEkraniState extends State<GecmisEkrani> {
  List<Map<String, dynamic>> _islemler = [];
  bool _yukleniyor = true;
  String _filtre = "TÜMÜ";

  @override
  void initState() { super.initState(); _cek(); }

  Future<void> _cek() async {
    setState(() => _yukleniyor = true);
    final v = await _panel("/gecmis_islemler");
    if (!mounted) return;
    setState(() {
      _islemler = (v is Map && v["islemler"] is List)
          ? (v["islemler"] as List)
              .map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _yukleniyor = false;
    });
  }

  Color _cikisRenk(String s) {
    final u = s.toUpperCase();
    if (u.contains("TRAIL")) return Renk.teal;
    if (u.contains("STOP")) return Renk.kirmizi;
    if (u.contains("BASABAS") || u.contains("BE")) return Renk.altin;
    return Renk.yaziSoluk;
  }

  @override
  Widget build(BuildContext context) {
    final gosterilen = _islemler.where((it) {
      if (_filtre == "TÜMÜ") return true;
      return (it["yon"]?.toString().toUpperCase() ?? "") == _filtre;
    }).toList();
    return RefreshIndicator(
      onRefresh: _cek, color: Renk.teal, backgroundColor: Renk.kart,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text("İŞLEM GEÇMİŞİ", style: _baslikStil),
        const SizedBox(height: 12),
        Row(children: [
          for (final f in ["TÜMÜ", "LONG", "SHORT"]) ...[
            _filtreCip(f), const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 14),
        if (_yukleniyor)
          const Padding(padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: Renk.teal)))
        else if (gosterilen.isEmpty)
          _bosKutu("Henüz kapanan işlem yok")
        else
          _kart(
            ic: EdgeInsets.zero,
            cocuk: Column(
              children: gosterilen.asMap().entries.map((e) {
                final it = e.value;
                final son = e.key == gosterilen.length - 1;
                final long = (it["yon"]?.toString().toUpperCase() ?? "") == "LONG";
                final pnl = _d(it["pnl"]);
                final sebep = (it["sebep"] ?? "").toString();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: son
                      ? null
                      : const BoxDecoration(
                          border: Border(bottom: BorderSide(
                              color: Renk.cizgi, width: 0.7))),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: Renk.kartAcik,
                          shape: BoxShape.circle,
                          border: Border.all(color: Renk.cizgi)),
                      alignment: Alignment.center,
                      child: Text(
                          (it["sembol"]?.toString() ?? "?").substring(0, 1),
                          style: const TextStyle(color: Renk.yazi,
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text(it["sembol"]?.toString() ?? "?",
                            style: const TextStyle(color: Renk.yazi,
                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: (long ? Renk.teal : Renk.kirmizi)
                                  .withOpacity(0.14),
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(long ? "LONG" : "SHORT",
                              style: TextStyle(
                                  color: long ? Renk.teal : Renk.kirmizi,
                                  fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text(it["zaman"]?.toString() ?? "",
                          style: const TextStyle(
                              color: Renk.yaziSoluk, fontSize: 10.5)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text(_para(pnl, isaret: true),
                          style: TextStyle(color: _pnlRenk(pnl),
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      if (sebep.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: _cikisRenk(sebep).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(sebep.toUpperCase(),
                              style: TextStyle(
                                  color: _cikisRenk(sebep), fontSize: 8.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ]),
                  ]),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _filtreCip(String ad) {
    final aktif = _filtre == ad;
    return GestureDetector(
      onTap: () => setState(() => _filtre = ad),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? Renk.teal : Renk.kart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: aktif ? Renk.teal : Renk.cizgi),
        ),
        child: Text(ad, style: TextStyle(
            color: aktif ? const Color(0xFF06251F) : Renk.yaziSoluk,
            fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
  }
}

// ============================================================
//  AYARLAR SAYFASI (YENI)
// ============================================================
class AyarlarSayfasi extends StatefulWidget {
  const AyarlarSayfasi({super.key});
  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  final _urlKontrol = TextEditingController(text: gPanelUrl);
  bool _kaydediliyor = false;

  Future<void> _urlKaydet() async {
    final yeni = _urlKontrol.text.trim();
    if (yeni.isEmpty) return;
    setState(() => _kaydediliyor = true);
    gPanelUrl = yeni;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('panel_url', yeni);
    } catch (_) {}
    await DurumServisi.instance.elleYenile();
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: Renk.kart,
      content: Text("Panel adresi güncellendi",
          style: TextStyle(color: Renk.yazi)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final v = DurumServisi.instance.veri;
    final rejim = (v?["rejim"] ?? "belirsiz").toString();
    final ayarlar = kRejimAyar[rejim] ?? kRejimAyar["belirsiz"]!;
    return Scaffold(
      backgroundColor: Renk.arkaplan,
      body: Stack(children: [
        const Positioned.fill(child: KodYagmuru()),
        Positioned.fill(
            child: Container(color: Renk.arkaplan.withOpacity(0.9))),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Renk.yazi),
              ),
              const Text("AYARLAR",
                  style: TextStyle(color: Renk.yazi, fontSize: 17,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.all(16),
              children: [
            const Text("BOT DURUMU", style: _kucukBaslik),
            const SizedBox(height: 10),
            _kart(cocuk: Column(children: [
              _ayarSatir("Rejim (BTC 4h)", _rejimAd(rejim),
                  renk: _rejimRenk(rejim)),
              const Divider(color: Renk.cizgi, height: 20),
              _ayarSatir("Aktif Ayar",
                  "GUC ${ayarlar[0]} · STOP ×${ayarlar[1]}"),
              const Divider(color: Renk.cizgi, height: 20),
              _ayarSatir("İzleme Listesi",
                  "TON · ETH · SOL · XRP · DOGE · LINK"),
            ])),
            const SizedBox(height: 20),
            const Text("PANEL BAĞLANTISI", style: _kucukBaslik),
            const SizedBox(height: 10),
            _kart(cocuk: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: DurumServisi.instance.bagliMi
                            ? Renk.teal : Renk.kirmizi,
                        shape: BoxShape.circle)),
                Text(DurumServisi.instance.bagliMi ? "Bağlı" : "Bağlantı yok",
                    style: TextStyle(
                        color: DurumServisi.instance.bagliMi
                            ? Renk.teal : Renk.kirmizi,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _urlKontrol,
                style: const TextStyle(color: Renk.yazi, fontSize: 13),
                decoration: InputDecoration(
                  filled: true, fillColor: Renk.kartAcik,
                  hintText: "http://127.0.0.1:8080",
                  hintStyle: const TextStyle(color: Renk.yaziSoluk),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _kaydediliyor ? null : _urlKaydet,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Renk.teal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(_kaydediliyor
                      ? "Kaydediliyor..." : "Kaydet ve Yenile",
                      style: const TextStyle(color: Renk.teal,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ])),
            const SizedBox(height: 20),
            const Text("HESAP", style: _kucukBaslik),
            const SizedBox(height: 10),
            _kart(
              ic: EdgeInsets.zero,
              cocuk: InkWell(
                onTap: () => _cikisYap(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(Icons.logout, color: Renk.kirmizi, size: 18),
                    SizedBox(width: 10),
                    Text("Çıkış Yap",
                        style: TextStyle(color: Renk.kirmizi,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ])),
        ])),
      ]),
    );
  }

  Widget _ayarSatir(String etiket, String deger, {Color? renk}) =>
      Row(children: [
        Text(etiket, style: const TextStyle(
            color: Renk.yaziSoluk, fontSize: 13)),
        const Spacer(),
        Flexible(child: Text(deger, textAlign: TextAlign.right,
            style: TextStyle(color: renk ?? Renk.yazi,
                fontWeight: FontWeight.w700, fontSize: 13))),
      ]);
}

// ============================================================
//  ÇİZİCİLER
// ============================================================
class _CizgiPainter extends CustomPainter {
  final List<double> noktalar;
  _CizgiPainter(this.noktalar);
  @override
  void paint(Canvas canvas, Size size) {
    if (noktalar.length < 2) return;
    final mn = noktalar.reduce(math.min);
    final mx = noktalar.reduce(math.max);
    final aralik = mx - mn;
    if (aralik == 0) return;
    final boya = Paint()
      ..color = Renk.teal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final dolgu = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Renk.teal.withOpacity(0.22), Renk.teal.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final yol = Path();
    final dolguYol = Path();
    for (int i = 0; i < noktalar.length; i++) {
      final x = i / (noktalar.length - 1) * size.width;
      final y = size.height - (noktalar[i] - mn) / aralik * size.height;
      if (i == 0) { yol.moveTo(x, y); dolguYol.moveTo(x, size.height); dolguYol.lineTo(x, y); }
      else { yol.lineTo(x, y); dolguYol.lineTo(x, y); }
    }
    dolguYol.lineTo(size.width, size.height); dolguYol.close();
    canvas.drawPath(dolguYol, dolgu);
    canvas.drawPath(yol, boya);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => true;
}

class _MumPainter extends CustomPainter {
  final List<Map<String, dynamic>> mumlar;
  final List<Map<String, dynamic>> seviyeler;
  _MumPainter(this.mumlar, this.seviyeler);
  @override
  void paint(Canvas canvas, Size size) {
    if (mumlar.isEmpty) return;
    final fiyatlar = mumlar.expand((m) => [_d(m["h"]), _d(m["l"])]).toList();
    final mn = fiyatlar.reduce(math.min);
    final mx = fiyatlar.reduce(math.max);
    if (mx == mn) return;
    double toY(double f) => size.height - (f - mn) / (mx - mn) * size.height;
    final genislik = size.width / mumlar.length;
    for (int i = 0; i < mumlar.length; i++) {
      final m = mumlar[i];
      final o = _d(m["o"]); final c = _d(m["c"]);
      final h = _d(m["h"]); final l = _d(m["l"]);
      final yukari = c >= o;
      final renk = yukari ? Renk.teal : Renk.kirmizi;
      final x = i * genislik + genislik / 2;
      final boya = Paint()..color = renk..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, toY(h)), Offset(x, toY(l)), boya);
      final govde = Paint()..color = renk..style = PaintingStyle.fill;
      final ust = toY(math.max(o, c));
      final alt = toY(math.min(o, c));
      canvas.drawRect(
          Rect.fromLTWH(i * genislik + 1, ust, genislik - 2, math.max(1, alt - ust)),
          govde);
    }
    final sevBoya = Paint()
      ..color = Renk.altin.withOpacity(0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final s in seviyeler) {
      final f = _d(s["fiyat"]);
      if (f < mn || f > mx) continue;
      final y = toY(f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), sevBoya);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => true;
}

class _Halka extends StatelessWidget {
  final double yuzde;
  final String etiket;
  final double boyut;
  const _Halka({required this.yuzde, required this.etiket, this.boyut = 80});
  @override
  Widget build(BuildContext context) {
    final renk = yuzde >= 0.66
        ? Renk.teal : (yuzde >= 0.4 ? Renk.altin : Renk.kirmizi);
    return SizedBox(
      width: boyut, height: boyut,
      child: Stack(children: [
        CustomPaint(
            size: Size(boyut, boyut),
            painter: _HalkaPainter(yuzde, renk)),
        Center(child: Text(etiket,
            style: TextStyle(color: renk, fontSize: boyut * 0.18,
                fontWeight: FontWeight.w700))),
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
    final cx = size.width / 2; final cy = size.height / 2;
    final r = math.min(cx, cy) - 4;
    final arka = Paint()..color = Renk.cizgi..strokeWidth = 6..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), r, arka);
    final on = Paint()
      ..color = renk..strokeWidth = 6..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * yuzde, false, on);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => true;
}

// ============================================================
//  KOD YAĞMURU (Matrix)
// ============================================================
class KodYagmuru extends StatefulWidget {
  const KodYagmuru({super.key});
  @override
  State<KodYagmuru> createState() => _KodYagmuruState();
}

class _KodYagmuruState extends State<KodYagmuru>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _random = math.Random();
  final List<_Sutun> _sutunlar = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80))
      ..addListener(_guncelle)
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _guncelle() {
    for (final s in _sutunlar) s.guncelle(_random);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, kisit) {
      final genislik = kisit.maxWidth;
      final yukseklik = kisit.maxHeight;
      if (_sutunlar.isEmpty && genislik > 0 && yukseklik > 0) {
        final sutunSayisi = (genislik / 14).floor();
        for (int i = 0; i < sutunSayisi; i++) {
          _sutunlar.add(_Sutun(i * 14, yukseklik, _random));
        }
      }
      return CustomPaint(
        painter: _YagmurPainter(_sutunlar),
        size: Size(genislik, yukseklik),
      );
    });
  }
}

class _Sutun {
  final double x;
  final double yukseklik;
  double y;
  double hiz;
  final List<String> karakterler = [];
  static const _list = "01アキンジIYERX∆₿ΞЖ";

  _Sutun(this.x, this.yukseklik, math.Random r)
      : y = 0,
        hiz = 1.5 + r.nextDouble() * 2.5 {
    y = -r.nextDouble() * yukseklik;
    for (int i = 0; i < 18; i++) {
      karakterler.add(_list[r.nextInt(_list.length)]);
    }
  }

  void guncelle(math.Random r) {
    y += hiz * 0.6;
    if (y > yukseklik + 200) {
      y = -r.nextDouble() * 200;
      hiz = 1.5 + r.nextDouble() * 2.5;
    }
    if (r.nextDouble() < 0.08) {
      final i = r.nextInt(karakterler.length);
      karakterler[i] = _list[r.nextInt(_list.length)];
    }
  }
}

class _YagmurPainter extends CustomPainter {
  final List<_Sutun> sutunlar;
  _YagmurPainter(this.sutunlar);
  @override
  void paint(Canvas canvas, Size size) {
    const boyut = 11.0;
    for (final s in sutunlar) {
      for (int i = 0; i < s.karakterler.length; i++) {
        final oran = i / s.karakterler.length;
        final opacity = (1.0 - oran) * 0.45;
        if (opacity <= 0) continue;
        final renk = i == s.karakterler.length - 1
            ? Renk.teal.withOpacity(0.9)
            : Renk.teal.withOpacity(opacity * 0.6);
        final boya = Paint();
        final textSpan = TextSpan(
            text: s.karakterler[i],
            style: TextStyle(color: renk, fontSize: boyut,
                fontWeight: FontWeight.w500));
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(s.x, s.y - i * (boyut + 3)));
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => true;
}
