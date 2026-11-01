import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_client_edit.dart';
import '../adguard_home_filter_rules.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_settings.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_settings_form.dart';

/// How the server answers: rate limiting, EDNS client subnet, DNSSEC,
/// IPv6, and what a blocked name gets. Saved with Save.
class AdguardHomeDnsServerScreen extends ConsumerStatefulWidget {
  const AdguardHomeDnsServerScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeDnsServerScreen> createState() =>
      _AdguardHomeDnsServerScreenState();
}

class _AdguardHomeDnsServerScreenState
    extends ConsumerState<AdguardHomeDnsServerScreen> {
  final TextEditingController _ratelimit = TextEditingController();
  final TextEditingController _subnet4 = TextEditingController();
  final TextEditingController _subnet6 = TextEditingController();
  final TextEditingController _allowlist = TextEditingController();
  final TextEditingController _ednsIp = TextEditingController();
  final TextEditingController _blockingIpv4 = TextEditingController();
  final TextEditingController _blockingIpv6 = TextEditingController();
  final TextEditingController _ttl = TextEditingController();

  AdguardHomeDnsConfig? _read;
  Map<String, dynamic>? _before;
  bool _edns = false;
  bool _ednsCustom = false;
  bool _dnssec = false;
  bool _noIpv6 = false;
  AdguardHomeBlockingMode _mode = AdguardHomeBlockingMode.normal;
  bool _checked = false;
  bool _busy = false;

  /// The fields typed in since the form opened: their problems show at
  /// once, the others' only after Save.
  final Set<String> _touched = <String>{};

  Instance get _instance => widget.instance;

  void _edited(String key) => setState(() => _touched.add(key));

  List<TextEditingController> get _fields => <TextEditingController>[
        _ratelimit,
        _subnet4,
        _subnet6,
        _allowlist,
        _ednsIp,
        _blockingIpv4,
        _blockingIpv6,
        _ttl,
      ];

  @override
  void dispose() {
    for (final TextEditingController field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _fill(AdguardHomeDnsConfig dns) {
    _ratelimit.text = '${dns.ratelimit}';
    _subnet4.text = '${dns.ratelimitSubnetIpv4}';
    _subnet6.text = '${dns.ratelimitSubnetIpv6}';
    _allowlist.text = adguardHomeRulesToText(dns.ratelimitWhitelist);
    _ednsIp.text = dns.ednsCustomIp;
    _blockingIpv4.text = dns.blockingIpv4;
    _blockingIpv6.text = dns.blockingIpv6;
    _ttl.text = '${dns.blockedResponseTtl}';
    _edns = dns.ednsEnabled;
    _ednsCustom = dns.ednsUseCustom;
    _dnssec = dns.dnssecEnabled;
    _noIpv6 = dns.disableIpv6;
    _mode = dns.blockingMode;
    _read = dns;
    _before = _json();
  }

  List<String> get _allowed => <String>[
        for (final String line in adguardHomeRulesFromText(_allowlist.text))
          line.trim(),
      ];

  /// What is wrong with each field, by its key, as far as the app can tell.
  /// The server judges the rest and says so.
  Map<String, String> get _problems {
    final Map<String, String> problems = <String, String>{};
    void check(String key, String? problem) {
      if (problem != null) problems[key] = problem;
    }

    check('ratelimit', adguardHomeWholeNumberProblem(_ratelimit.text));
    check('subnet4', adguardHomeWholeNumberProblem(_subnet4.text, max: 32));
    check('subnet6', adguardHomeWholeNumberProblem(_subnet6.text, max: 128));
    for (final String address in _allowed) {
      if (adguardHomeIpProblem(address) != null) {
        problems['allowlist'] = '"$address" is not an IP address.';
        break;
      }
    }
    if (_edns && _ednsCustom) {
      check('ednsIp', adguardHomeIpProblem(_ednsIp.text));
    }
    if (_mode == AdguardHomeBlockingMode.customIp) {
      check('ipv4', adguardHomeIpProblem(_blockingIpv4.text, version: 4));
      check('ipv6', adguardHomeIpProblem(_blockingIpv6.text, version: 6));
    }
    check('ttl', adguardHomeWholeNumberProblem(_ttl.text));
    return problems;
  }

  /// The settings as `dns_config` takes them. Only meaningful without
  /// [_problems].
  Map<String, dynamic> _json() => <String, dynamic>{
        'ratelimit': int.tryParse(_ratelimit.text.trim()),
        'ratelimit_subnet_len_ipv4': int.tryParse(_subnet4.text.trim()),
        'ratelimit_subnet_len_ipv6': int.tryParse(_subnet6.text.trim()),
        'ratelimit_whitelist': _allowed,
        'edns_cs_enabled': _edns,
        'edns_cs_use_custom': _ednsCustom,
        // A box that is hidden goes as the server has it: what was typed
        // there and left is not checked, and must not be sent.
        'edns_cs_custom_ip':
            _edns && _ednsCustom ? _ednsIp.text.trim() : _read!.ednsCustomIp,
        'dnssec_enabled': _dnssec,
        'disable_ipv6': _noIpv6,
        'blocking_mode': _mode.wire,
        'blocking_ipv4': _mode == AdguardHomeBlockingMode.customIp
            ? _blockingIpv4.text.trim()
            : _read!.blockingIpv4,
        'blocking_ipv6': _mode == AdguardHomeBlockingMode.customIp
            ? _blockingIpv6.text.trim()
            : _read!.blockingIpv6,
        'blocked_response_ttl': int.tryParse(_ttl.text.trim()),
      };

  bool get _changed {
    final Map<String, dynamic>? before = _before;
    if (before == null) return false;
    return adguardHomeChangedSettings(before, _json()).isNotEmpty;
  }

  Future<void> _save() async {
    final Map<String, dynamic>? before = _before;
    if (_busy || before == null) return;
    if (_problems.isNotEmpty) {
      setState(() => _checked = true);
      return;
    }
    final Map<String, dynamic> after = _json();
    await adguardHomeSaveSettings(
      context,
      ref,
      _instance,
      save: () => ref
          .read(adguardHomeActionsProvider(_instance))
          .saveDnsSettings(before: before, after: after),
      done: 'DNS server settings saved',
      setBusy: (bool busy) => setState(() => _busy = busy),
      retry: _save,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeDnsConfig> read =
        ref.watch(adguardHomeDnsConfigProvider(_instance));
    final AdguardHomeDnsConfig? value = read.value;
    // Filled once. A later read must not replace what is being typed.
    if (_before == null && value != null) _fill(value);
    return AdguardHomeSettingsForm(
      title: 'DNS server',
      busy: _busy,
      changed: _changed,
      onSave: _save,
      body: _before == null
          ? adguardHomeSettingsWaiting<AdguardHomeDnsConfig>(
                context,
                ref,
                _instance,
                read,
                onRetry: () =>
                    ref.invalidate(adguardHomeDnsConfigProvider(_instance)),
              ) ??
              const SizedBox.shrink()
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final Map<String, String> problems = _problems;
    String? shown(String key) =>
        _checked || _touched.contains(key) ? problems[key] : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      children: <Widget>[
        const AdguardHomeHeading('Rate limit'),
        const SizedBox(height: Insets.sm),
        _number(
          'ratelimit',
          _ratelimit,
          'Requests a second',
          'Allowed from one client. 0 is no limit.',
          shown('ratelimit'),
        ),
        _number(
          'subnet4',
          _subnet4,
          'IPv4 subnet prefix length',
          'Clients in one subnet this wide share a limit. The default is 24.',
          shown('subnet4'),
        ),
        _number(
          'subnet6',
          _subnet6,
          'IPv6 subnet prefix length',
          'The same for IPv6. The default is 56.',
          shown('subnet6'),
        ),
        TextField(
          key: const Key('adguard-ratelimit-allowlist'),
          controller: _allowlist,
          onChanged: (_) => _edited('allowlist'),
          minLines: 2,
          maxLines: 8,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Not limited',
            helperText: 'IP addresses left out of the rate limit, one per '
                'line',
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            errorText: shown('allowlist'),
          ),
        ),
        const AdguardHomeHeading('Requests'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('EDNS client subnet'),
          subtitle: const Text(
            "Send part of the client's address to the upstream servers, and "
            'log what clients send',
          ),
          value: _edns,
          onChanged: (bool on) => setState(() => _edns = on),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use a custom IP for EDNS'),
          value: _ednsCustom,
          onChanged:
              _edns ? (bool on) => setState(() => _ednsCustom = on) : null,
        ),
        if (_edns && _ednsCustom)
          _address('ednsIp', _ednsIp, 'EDNS IP address', shown('ednsIp')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('DNSSEC'),
          subtitle: const Text(
            'Ask for DNSSEC and check the answers. The upstream servers have '
            'to support it',
          ),
          value: _dnssec,
          onChanged: (bool on) => setState(() => _dnssec = on),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disable resolving of IPv6 addresses'),
          subtitle: const Text('Drop every query for an IPv6 address (AAAA)'),
          value: _noIpv6,
          onChanged: (bool on) => setState(() => _noIpv6 = on),
        ),
        const AdguardHomeHeading('Blocking mode'),
        RadioGroup<AdguardHomeBlockingMode>(
          groupValue: _mode,
          onChanged: (AdguardHomeBlockingMode? mode) {
            if (mode != null) setState(() => _mode = mode);
          },
          child: Column(
            children: <Widget>[
              for (final AdguardHomeBlockingMode mode
                  in AdguardHomeBlockingMode.values)
                RadioListTile<AdguardHomeBlockingMode>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(mode.label),
                  subtitle: Text(_modeHelp(mode)),
                  value: mode,
                ),
            ],
          ),
        ),
        if (_mode == AdguardHomeBlockingMode.customIp) ...<Widget>[
          _address('ipv4', _blockingIpv4, 'For IPv4 (A)', shown('ipv4')),
          _address('ipv6', _blockingIpv6, 'For IPv6 (AAAA)', shown('ipv6')),
        ],
        const SizedBox(height: Insets.sm),
        _number(
          'ttl',
          _ttl,
          'Blocked response TTL',
          'Seconds a client may keep a blocked answer.',
          shown('ttl'),
        ),
      ],
    );
  }

  static String _modeHelp(AdguardHomeBlockingMode mode) => switch (mode) {
        AdguardHomeBlockingMode.normal =>
          'Zero address for a blocklist rule, the rule\'s own address for a '
              'hosts-style one',
        AdguardHomeBlockingMode.refused => 'Answer with REFUSED',
        AdguardHomeBlockingMode.nxdomain => 'Answer with NXDOMAIN',
        AdguardHomeBlockingMode.nullIp =>
          'Answer with the zero address, 0.0.0.0 or ::',
        AdguardHomeBlockingMode.customIp => 'Answer with addresses set here',
      };

  Widget _number(
    String key,
    TextEditingController controller,
    String label,
    String helper,
    String? error,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: TextField(
          key: Key('adguard-dns-$key'),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => _edited(key),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            errorText: error,
          ),
        ),
      );

  Widget _address(
    String key,
    TextEditingController controller,
    String label,
    String? error,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: TextField(
          key: Key('adguard-dns-$key'),
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => _edited(key),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: error,
          ),
        ),
      );
}
