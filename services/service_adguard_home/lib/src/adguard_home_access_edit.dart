import 'models/adguard_home_access.dart';

/// The access list after the client at [address] is shut out, or let back
/// in when it is [disallowed] now.
///
/// These are the web UI's own steps (`getNextClientAccessList` in
/// `client/src/actions/access.ts`), so the lists end up as they would from
/// there:
///
///  * a client that is shut out because only the allowed clients are
///    answered is added to the allowed clients;
///  * a client that is shut out by an entry of the disallowed clients has
///    that entry, [disallowedRule], removed. It can be a range. Where the
///    server named none, the address itself is removed;
///  * a client that is let in while only the allowed clients are answered
///    is taken off the allowed clients;
///  * otherwise it is added to the disallowed clients.
///
/// The blocked hosts go back as they came: the server replaces all three
/// lists on every write. [list] is not changed.
AdguardHomeAccessList adguardHomeClientAccessEdit(
  AdguardHomeAccessList list, {
  required String address,
  required bool disallowed,
  required String disallowedRule,
}) {
  List<String> allowed = list.allowedClients;
  List<String> shutOut = list.disallowedClients;

  if (disallowed && list.allowlistInUse) {
    allowed = _with(allowed, address);
  } else if (disallowed) {
    shutOut = _without(
      shutOut,
      disallowedRule.isEmpty ? address : disallowedRule,
    );
  } else if (list.allowlistInUse) {
    allowed = _without(allowed, address);
  } else {
    shutOut = _with(shutOut, address);
  }

  return AdguardHomeAccessList(
    allowedClients: allowed,
    disallowedClients: shutOut,
    blockedHosts: list.blockedHosts,
  );
}

/// Whether shutting out the client at [address] would take the last entry
/// off the allowed clients.
///
/// That must not be done from a row: an empty list of allowed clients
/// answers everyone, which is the opposite of what was asked. The web UI
/// disables its button for the same case.
bool adguardHomeIsLastAllowedClient(
  AdguardHomeAccessList list,
  String address, {
  required bool disallowed,
}) =>
    !disallowed &&
    list.allowedClients.length == 1 &&
    list.allowedClients.single == address;

List<String> _with(List<String> items, String value) =>
    items.contains(value) ? items : <String>[...items, value];

List<String> _without(List<String> items, String value) => <String>[
      for (final String item in items)
        if (item != value) item,
    ];
