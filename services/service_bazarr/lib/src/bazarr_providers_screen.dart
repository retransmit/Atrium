import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';

/// Display names for Bazarr's subtitle providers (key -> name). The settings
/// object mixes provider sections with config sections, so this is the
/// authoritative provider universe.
const Map<String, String> kBazarrProviders = <String, String>{
  'addic7ed': 'Addic7ed',
  'animekalesi': 'AnimeKalesi',
  'animetosho': 'Anime Tosho',
  'animesubinfo': 'AnimeSub.info',
  'avistaz': 'AvistaZ',
  'assrt': 'Assrt',
  'betaseries': 'BetaSeries',
  'bsplayer': 'BSplayer',
  'cinemaz': 'CinemaZ',
  'embeddedsubtitles': 'Embedded Subtitles',
  'gestdown': 'Gestdown (Addic7ed proxy)',
  'greeksubs': 'GreekSubs',
  'greeksubtitles': 'GreekSubtitles',
  'hdbits': 'HDBits.org',
  'jimaku': 'Jimaku.cc',
  'hosszupuska': 'Hosszupuska',
  'karagarga': 'Karagarga.in',
  'ktuvit': 'Ktuvit',
  'legendasdivx': 'LegendasDivx',
  'legendasnet': 'Legendas.net',
  'napiprojekt': 'NapiProjekt',
  'napisy24': 'Napisy24',
  'nekur': 'Nekur',
  'opensubtitlescom': 'OpenSubtitles.com',
  'podnapisi': 'Podnapisi',
  'regielive': 'RegieLive',
  'soustitreseu': 'Sous-Titres.eu',
  'subdl': 'SubDL',
  'subf2m': 'subf2m.co',
  'subsource': 'subsource.net',
  'subssabbz': 'Subs.sab.bz',
  'subs4free': 'Subs4Free',
  'subs4series': 'Subs4Series',
  'subscenter': 'SubsCenter',
  'subsro': 'subs.ro',
  'subsunacs': 'Subsunacs.net',
  'subsynchro': 'Subsynchro',
  'subtis': 'Subtis',
  'subtitrarinoi': 'Subtitrari-noi.ro',
  'subtitriid': 'subtitri.id.lv',
  'subtitulamostv': 'Subtitulamos.tv',
  'subx': 'SubX',
  'supersubtitles': 'Supersubtitles',
  'titlovi': 'Titlovi',
  'titrari': 'Titrari.ro',
  'titulky': 'Titulky.com',
  'turkcealtyaziorg': 'Turkcealtyazi.org',
  'tvsubtitles': 'TVSubtitles',
  'whisperai': 'Whisper',
  'wizdom': 'Wizdom',
  'xsubs': 'XSubs',
  'yavkanet': 'Yavka.net',
  'yifysubtitles': 'YIFY Subtitles',
  'zimuku': 'Zimuku',
};

/// Settings > Providers: enable/disable subtitle providers (toggle + Save),
/// tap a provider to configure its credentials/options.
class BazarrProvidersScreen extends ConsumerStatefulWidget {
  const BazarrProvidersScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<BazarrProvidersScreen> createState() =>
      _BazarrProvidersScreenState();
}

class _BazarrProvidersScreenState extends ConsumerState<BazarrProvidersScreen> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _enabled = <String>{};
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final BazarrApi api =
          await ref.read(bazarrApiProvider(widget.instance).future);
      await api.setEnabledProviders(_enabled.toList());
      ref.invalidate(bazarrSettingsProvider(widget.instance));
      ref.invalidate(bazarrProviderStatusesProvider(widget.instance));
      messenger.showSnackBar(const SnackBar(content: Text('Providers saved')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: ${_err(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, dynamic>> settings =
        ref.watch(bazarrSettingsProvider(widget.instance));
    return Scaffold(
      appBar: AppBar(
        title: Text('Providers (${_enabled.length})'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_outlined),
              onPressed: _seeded ? _save : null,
            ),
        ],
      ),
      body: AsyncValueView<Map<String, dynamic>>(
        value: settings,
        onRetry: () => ref.invalidate(bazarrSettingsProvider(widget.instance)),
        data: (Map<String, dynamic> s) {
          if (!_seeded) {
            final List<dynamic> on =
                ((s['general'] as Map<String, dynamic>?)?['enabled_providers']
                        as List<dynamic>?) ??
                    const <dynamic>[];
            _enabled
              ..clear()
              ..addAll(on.map((dynamic e) => e.toString()));
            _seeded = true;
          }
          final String q = _query.text.trim().toLowerCase();
          final List<MapEntry<String, String>> entries = kBazarrProviders.entries
              .where((MapEntry<String, String> e) =>
                  q.isEmpty ||
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q),)
              .toList()
            ..sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
                a.value.toLowerCase().compareTo(b.value.toLowerCase()),);
          return Column(
            children: <Widget>[
              Padding(
                padding: Insets.page,
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    hintText: 'Search providers...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (BuildContext context, int i) {
                    final MapEntry<String, String> p = entries[i];
                    return ListTile(
                      title: Text(p.value),
                      subtitle: const Text('Tap to configure'),
                      trailing: Switch(
                        value: _enabled.contains(p.key),
                        onChanged: (bool v) => setState(() {
                          if (v) {
                            _enabled.add(p.key);
                          } else {
                            _enabled.remove(p.key);
                          }
                        }),
                      ),
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute<void>(
                        builder: (_) => BazarrProviderConfigScreen(
                          instance: widget.instance,
                          providerKey: p.key,
                          providerName: p.value,
                        ),
                      ),),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Per-provider config: renders the provider's live settings section as fields
/// (switches for booleans, obscured text for credentials, text otherwise) and
/// saves them as `settings-<provider>-<key>`.
class BazarrProviderConfigScreen extends ConsumerStatefulWidget {
  const BazarrProviderConfigScreen({
    required this.instance,
    required this.providerKey,
    required this.providerName,
    super.key,
  });

  final Instance instance;
  final String providerKey;
  final String providerName;

  @override
  ConsumerState<BazarrProviderConfigScreen> createState() =>
      _BazarrProviderConfigScreenState();
}

class _BazarrProviderConfigScreenState
    extends ConsumerState<BazarrProviderConfigScreen> {
  final Map<String, dynamic> _values = <String, dynamic>{};
  bool _seeded = false;
  bool _saving = false;

  bool _isSecret(String key) {
    final String k = key.toLowerCase();
    return k.contains('password') ||
        k.contains('apikey') ||
        k.contains('api_key') ||
        k.contains('token') ||
        k.contains('cookies') ||
        k.contains('passkey') ||
        k.contains('secret');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    try {
      final BazarrApi api =
          await ref.read(bazarrApiProvider(widget.instance).future);
      final Map<String, String> fields = <String, String>{
        for (final MapEntry<String, dynamic> e in _values.entries)
          e.key: e.value is bool
              ? (e.value == true ? 'true' : 'false')
              : '${e.value}',
      };
      await api.setProviderConfig(widget.providerKey, fields);
      ref.invalidate(bazarrSettingsProvider(widget.instance));
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.providerName} saved')),
      );
      nav.pop();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: ${_err(e)}')),
      );
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> settings =
        ref.watch(bazarrSettingsProvider(widget.instance));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.providerName, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_outlined),
              onPressed: _seeded ? _save : null,
            ),
        ],
      ),
      body: AsyncValueView<Map<String, dynamic>>(
        value: settings,
        onRetry: () => ref.invalidate(bazarrSettingsProvider(widget.instance)),
        data: (Map<String, dynamic> s) {
          final Map<String, dynamic> section =
              (s[widget.providerKey] as Map<String, dynamic>?) ??
                  <String, dynamic>{};
          // Only scalar fields are editable generically.
          final List<MapEntry<String, dynamic>> fields = section.entries
              .where((MapEntry<String, dynamic> e) =>
                  e.value is bool || e.value is String || e.value is num,)
              .toList()
            ..sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) =>
                a.key.compareTo(b.key),);
          if (!_seeded) {
            _values.clear();
            for (final MapEntry<String, dynamic> e in fields) {
              _values[e.key] = e.value;
            }
            _seeded = true;
          }
          if (fields.isEmpty) {
            return const EmptyView(
              icon: Icons.tune,
              title: 'No editable settings',
              message: 'This provider has no scalar options to configure here.',
            );
          }
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              Text(
                'Enable this provider on the Providers list. Fields below map to '
                'Bazarr settings-${widget.providerKey}-*.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: Insets.md),
              for (final MapEntry<String, dynamic> e in fields)
                _field(e.key),
            ],
          );
        },
      ),
    );
  }

  Widget _field(String key) {
    final dynamic value = _values[key];
    if (value is bool) {
      final ThemeData theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.only(bottom: Insets.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: Radii.card,
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
          title: Text(key),
          value: value,
          onChanged: (bool v) => setState(() => _values[key] = v),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextFormField(
        key: ValueKey<String>(key),
        initialValue: '${value ?? ''}',
        obscureText: _isSecret(key),
        decoration: InputDecoration(
          labelText: key,
          border: const OutlineInputBorder(),
        ),
        onChanged: (String v) => _values[key] = v,
      ),
    );
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
