import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const mor = Color(0xFF8B5CF6), antrasit = Color(0xFF1E1E24), siyah = Color(0xFF0A0A0D);

class Store extends ChangeNotifier {
  final player = AudioPlayer();
  final query = OnAudioQuery();
  List<SongModel> songs = [];
  Set<int> favs = {};
  Map<String, List<int>> lists = {};
  bool izinYok = false, yukleniyor = true;
  SharedPreferences? sp;

  Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    favs = (sp!.getStringList('fav') ?? []).map(int.parse).toSet();
    final l = sp!.getString('lists');
    if (l != null) {
      lists = (jsonDecode(l) as Map).map((k, v) => MapEntry(k as String, List<int>.from(v)));
    }
    await tara();
  }

  Future<void> tara() async {
    yukleniyor = true; notifyListeners();
    var d = await Permission.audio.request();
    if (!d.isGranted) d = await Permission.storage.request();
    if (!d.isGranted) { izinYok = true; yukleniyor = false; notifyListeners(); return; }
    izinYok = false;
    try {
      final r = await query.querySongs(sortType: SongSortType.TITLE, uriType: UriType.EXTERNAL);
      const uz = ['mp3', 'wav', 'flac', 'aac', 'm4a'];
      songs = r.where((s) => s.isMusic == true && uz.contains(s.fileExtension.toLowerCase())).toList();
    } catch (_) { songs = []; }
    yukleniyor = false; notifyListeners();
  }

  void kaydet() {
    sp?.setStringList('fav', favs.map((e) => '$e').toList());
    sp?.setString('lists', jsonEncode(lists));
    notifyListeners();
  }

  void favDegis(SongModel s) { favs.contains(s.id) ? favs.remove(s.id) : favs.add(s.id); kaydet(); }

  Future<void> cal(List<SongModel> liste, int i) async {
    try {
      final src = ConcatenatingAudioSource(children: [
        for (final s in liste)
          AudioSource.uri(Uri.parse(s.uri!),
              tag: MediaItem(
                  id: '${s.id}', title: s.title, artist: s.artist ?? 'Bilinmeyen sanatçı',
                  album: s.album, artUri: Uri.parse('content://media/external/audio/albumart/${s.albumId}')))
      ]);
      await player.setAudioSource(src, initialIndex: i);
      player.play();
    } catch (_) {}
  }

  List<SongModel> idler(Iterable<int> ids) => songs.where((s) => ids.contains(s.id)).toList();
}

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
      androidNotificationChannelId: 'com.kisisel.benim_muzik.audio',
      androidNotificationChannelName: 'Müzik çalma',
      androidNotificationOngoing: true);
  runApp(const App());
  store.init();
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Müzik',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: siyah,
            colorScheme: const ColorScheme.dark(primary: mor, surface: antrasit),
            sliderTheme: const SliderThemeData(activeTrackColor: mor, thumbColor: mor)),
        home: const Ana(),
      );
}

class Ana extends StatefulWidget {
  const Ana({super.key});
  @override
  State<Ana> createState() => _AnaState();
}

class _AnaState extends State<Ana> {
  int sekme = 0;
  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final sayfalar = [
            const Sarkilar(),
            SarkiListesi(store.idler(store.favs), bos: 'Henüz favori şarkın yok.'),
            const Listeler()
          ];
          return Scaffold(
            body: SafeArea(child: sayfalar[sekme]),
            bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
              const MiniOynatici(),
              NavigationBar(
                  backgroundColor: antrasit,
                  selectedIndex: sekme,
                  onDestinationSelected: (i) => setState(() => sekme = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.music_note), label: 'Şarkılar'),
                    NavigationDestination(icon: Icon(Icons.favorite), label: 'Favoriler'),
                    NavigationDestination(icon: Icon(Icons.queue_music), label: 'Listeler'),
                  ]),
            ]),
          );
        },
      );
}

class Sarkilar extends StatefulWidget {
  const Sarkilar({super.key});
  @override
  State<Sarkilar> createState() => _SarkilarState();
}

class _SarkilarState extends State<Sarkilar> {
  String q = '';
  @override
  Widget build(BuildContext c) {
    if (store.izinYok) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Müzikleri bulmak için izin gerekli.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: store.tara, child: const Text('İzin ver')),
      ]));
    }
    if (store.yukleniyor) return const Center(child: CircularProgressIndicator(color: mor));
    final f = store.songs
        .where((s) => '${s.title} ${s.artist} ${s.album}'.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                  hintText: 'Şarkı, sanatçı veya albüm ara',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: antrasit,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
      Expanded(child: SarkiListesi(f, bos: 'Şarkı bulunamadı.')),
    ]);
  }
}

class SarkiListesi extends StatelessWidget {
  final List<SongModel> liste;
  final String bos;
  final String? listeAdi;
  const SarkiListesi(this.liste, {super.key, required this.bos, this.listeAdi});
  @override
  Widget build(BuildContext c) {
    if (liste.isEmpty) return Center(child: Text(bos));
    return ListView.builder(
      itemCount: liste.length,
      itemBuilder: (c, i) {
        final s = liste[i];
        return ListTile(
          leading: Kapak(s.id, 48),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${s.artist ?? "Bilinmeyen sanatçı"} • ${s.album ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => store.cal(liste, i),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'fav') store.favDegis(s);
              if (v == 'cikar' && listeAdi != null) { store.lists[listeAdi!]!.remove(s.id); store.kaydet(); }
              if (v == 'liste') {
                final ad = await showDialog<String>(
                    context: c,
                    builder: (_) => SimpleDialog(title: const Text('Çalma listesi seç'), children: [
                          if (store.lists.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Önce Listeler sekmesinden liste oluştur.')),
                          for (final k in store.lists.keys) SimpleDialogOption(onPressed: () => Navigator.pop(c, k), child: Text(k))
                        ]));
                if (ad != null) { store.lists[ad]!.add(s.id); store.kaydet(); }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'fav', child: Text(store.favs.contains(s.id) ? 'Favorilerden çıkar' : 'Favorilere ekle')),
              const PopupMenuItem(value: 'liste', child: Text('Çalma listesine ekle')),
              if (listeAdi != null) const PopupMenuItem(value: 'cikar', child: Text('Listeden çıkar')),
            ],
          ),
        );
      },
    );
  }
}

class Kapak extends StatelessWidget {
  final int id;
  final double boyut;
  const Kapak(this.id, this.boyut, {super.key});
  @override
  Widget build(BuildContext c) => QueryArtworkWidget(
        id: id,
        type: ArtworkType.AUDIO,
        size: 500,
        artworkWidth: boyut,
        artworkHeight: boyut,
        artworkBorder: BorderRadius.circular(boyut / 6),
        nullArtworkWidget: Container(
            width: boyut,
            height: boyut,
            decoration: BoxDecoration(color: antrasit, borderRadius: BorderRadius.circular(boyut / 6)),
            child: Icon(Icons.music_note, color: mor, size: boyut / 2)),
      );
}

class Listeler extends StatelessWidget {
  const Listeler({super.key});
  @override
  Widget build(BuildContext c) => Column(children: [
        ListTile(
            leading: const Icon(Icons.add_circle, color: mor),
            title: const Text('Yeni çalma listesi'),
            onTap: () async {
              final t = TextEditingController();
              final ad = await showDialog<String>(
                  context: c,
                  builder: (_) => AlertDialog(
                      title: const Text('Liste adı'),
                      content: TextField(controller: t, autofocus: true),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')), TextButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('Oluştur'))]));
              if (ad != null && ad.isNotEmpty) { store.lists.putIfAbsent(ad, () => []); store.kaydet(); }
            }),
        Expanded(
            child: ListView(children: [
          for (final k in store.lists.keys)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(k),
              subtitle: Text('${store.lists[k]!.length} şarkı'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { store.lists.remove(k); store.kaydet(); }),
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ListenableBuilder(listenable: store, builder: (_, __) => Scaffold(appBar: AppBar(title: Text(k)), body: SarkiListesi(store.idler(store.lists[k] ?? []), bos: 'Liste boş.', listeAdi: k))))),
            )
        ])),
      ]);
}

MediaItem? _mevcut() {
  final t = store.player.sequenceState?.currentSource?.tag;
  return t is MediaItem ? t : null;
}

class MiniOynatici extends StatelessWidget {
  const MiniOynatici({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<SequenceState?>(
        stream: store.player.sequenceStateStream,
        builder: (c, _) {
          final m = _mevcut();
          if (m == null) return const SizedBox.shrink();
          return InkWell(
            onTap: () => Navigator.push(c, PageRouteBuilder(pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const OynatPage()))),
            child: Container(
              color: const Color(0xFF2A1F45),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Kapak(int.parse(m.id), 44),
                const SizedBox(width: 12),
                Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                StreamBuilder<bool>(
                    stream: store.player.playingStream,
                    builder: (c, s) => IconButton(
                        icon: Icon(s.data == true ? Icons.pause : Icons.play_arrow),
                        onPressed: () => s.data == true ? store.player.pause() : store.player.play())),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: store.player.seekToNext),
              ]),
            ),
          );
        },
      );
}

String sure(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class OynatPage extends StatelessWidget {
  const OynatPage({super.key});
  @override
  Widget build(BuildContext c) {
    final p = store.player;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 32), onPressed: () => Navigator.pop(c)), title: const Text('Şimdi çalıyor')),
      body: StreamBuilder<SequenceState?>(
        stream: p.sequenceStateStream,
        builder: (c, _) {
          final m = _mevcut();
          if (m == null) return const SizedBox.shrink();
          final id = int.parse(m.id);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Container(decoration: BoxDecoration(boxShadow: [BoxShadow(color: mor.withOpacity(.4), blurRadius: 50)]), child: Kapak(id, MediaQuery.of(c).size.width - 80)),
              const Spacer(),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${m.artist ?? ""}', style: const TextStyle(color: Colors.white60)),
                ])),
                ListenableBuilder(listenable: store, builder: (_, __) => IconButton(icon: Icon(store.favs.contains(id) ? Icons.favorite : Icons.favorite_border, color: mor), onPressed: () { final s = store.songs.where((x) => x.id == id); if (s.isNotEmpty) store.favDegis(s.first); })),
              ]),
              StreamBuilder<Duration>(
                  stream: p.positionStream,
                  builder: (c, s) {
                    final pos = s.data ?? Duration.zero, top = p.duration ?? Duration.zero;
                    final v = pos.inMilliseconds.clamp(0, top.inMilliseconds == 0 ? 1 : top.inMilliseconds).toDouble();
                    return Column(children: [
                      Slider(value: v, max: top.inMilliseconds == 0 ? 1 : top.inMilliseconds.toDouble(), onChanged: (x) => p.seek(Duration(milliseconds: x.toInt()))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(sure(pos)), Text(sure(top))])),
                    ]);
                  }),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                StreamBuilder<bool>(stream: p.shuffleModeEnabledStream, builder: (c, s) => IconButton(icon: Icon(Icons.shuffle, color: s.data == true ? mor : Colors.white54), onPressed: () => p.setShuffleModeEnabled(!(s.data ?? false)))),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous), onPressed: p.seekToPrevious),
                StreamBuilder<bool>(stream: p.playingStream, builder: (c, s) => IconButton(iconSize: 64, color: mor, icon: Icon(s.data == true ? Icons.pause_circle_filled : Icons.play_circle_filled), onPressed: () => s.data == true ? p.pause() : p.play())),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_next), onPressed: p.seekToNext),
                StreamBuilder<LoopMode>(stream: p.loopModeStream, builder: (c, s) {
                  final l = s.data ?? LoopMode.off;
                  return IconButton(icon: Icon(l == LoopMode.one ? Icons.repeat_one : Icons.repeat, color: l == LoopMode.off ? Colors.white54 : mor), onPressed: () => p.setLoopMode(LoopMode.values[(l.index + 1) % 3]));
                }),
              ]),
              StreamBuilder<double>(stream: p.volumeStream, builder: (c, s) => Row(children: [const Icon(Icons.volume_down), Expanded(child: Slider(value: s.data ?? 1, onChanged: p.setVolume)), const Icon(Icons.volume_up)])),
            ]),
          );
        },
      ),
    );
  }
}
