/// Torrent rows and property maps shaped the way qBittorrent sends them.
///
/// The keys are qBittorrent's own, read from its serializer at the release
/// tags (`serialize_torrent.cpp` and `torrentscontroller.cpp`), since the
/// three generations below differ in exactly what these tests are about:
///
///  * 4.3.9 (WebAPI 2.8.2): nothing says whether a torrent is private.
///  * 4.6.7 (WebAPI 2.9.3): a torrent's properties carry `is_private`; the
///    rows of the list still say nothing.
///  * 5.1.2 (WebAPI 2.11.4): rows and properties both carry `private`, which
///    is null until a magnet's metadata is in. `is_private` is kept beside it.
library;

enum QbitRelease { v439, v467, v512 }

const String qbitFixtureHash = '8c212779b4abde7c6bc608063a0d008b7e40ce32';

const int _size = 790626304;

/// One row of `GET /api/v2/torrents/info`.
///
/// [private] is what the torrent itself says. [hasMetadata] false is a magnet
/// still fetching its metadata, where no release knows the answer yet.
Map<String, dynamic> torrentRowJson({
  QbitRelease release = QbitRelease.v512,
  String hash = qbitFixtureHash,
  String name = 'debian-13.1.0-amd64-netinst.iso',
  String state = 'stalledUP',
  bool private = false,
  bool hasMetadata = true,
  double progress = 1,
  int dlspeed = 0,
  int upspeed = 0,
  int eta = 8640000,
}) {
  final bool since46 = release != QbitRelease.v439;
  final bool since50 = release == QbitRelease.v512;
  return <String, dynamic>{
    'hash': hash,
    if (since46) 'infohash_v1': hash,
    if (since46) 'infohash_v2': '',
    'name': name,
    'magnet_uri': 'magnet:?xt=urn:btih:$hash&dn=$name',
    'size': hasMetadata ? _size : 0,
    'progress': progress,
    'dlspeed': dlspeed,
    'upspeed': upspeed,
    'priority': 0,
    'num_seeds': 0,
    'num_complete': 212,
    'num_leechs': 0,
    'num_incomplete': 9,
    'state': state,
    'eta': eta,
    'seq_dl': false,
    'f_l_piece_prio': false,
    'category': '',
    'tags': '',
    'super_seeding': false,
    'force_start': false,
    'save_path': '/data/torrents',
    if (since46) 'download_path': '',
    'content_path': '/data/torrents/$name',
    if (since50) 'root_path': '',
    'added_on': 1790000000,
    'completion_on': 1790003600,
    'tracker': '',
    'trackers_count': 1,
    'dl_limit': 0,
    'up_limit': 0,
    'downloaded': hasMetadata ? _size : 0,
    'uploaded': 0,
    'downloaded_session': 0,
    'uploaded_session': 0,
    'amount_left': 0,
    'completed': hasMetadata ? _size : 0,
    'max_ratio': -1,
    'max_seeding_time': -1,
    if (since46) 'max_inactive_seeding_time': -1,
    'ratio': 0,
    'ratio_limit': -2,
    if (since50) 'popularity': 0,
    'seeding_time_limit': -2,
    if (since46) 'inactive_seeding_time_limit': -2,
    'seen_complete': 1790003600,
    'auto_tmm': false,
    'time_active': 3600,
    'seeding_time': 0,
    'last_activity': 1790003600,
    'availability': -1,
    if (since50) 'reannounce': 0,
    if (since50) 'comment': '',
    if (since50) 'private': hasMetadata ? private : null,
    'total_size': hasMetadata ? _size : -1,
    if (since50) 'has_metadata': hasMetadata,
  };
}

/// The answer of `GET /api/v2/torrents/properties`.
Map<String, dynamic> torrentPropertiesJson({
  QbitRelease release = QbitRelease.v512,
  String hash = qbitFixtureHash,
  String name = 'debian-13.1.0-amd64-netinst.iso',
  bool private = false,
  bool hasMetadata = true,
  int dlSpeed = 0,
  int upSpeed = 0,
}) {
  final bool since46 = release != QbitRelease.v439;
  final bool since50 = release == QbitRelease.v512;
  return <String, dynamic>{
    if (since46) 'infohash_v1': hash,
    if (since46) 'infohash_v2': '',
    if (since46) 'name': name,
    if (since46) 'hash': hash,
    'time_elapsed': 3600,
    'seeding_time': 0,
    'eta': 8640000,
    'nb_connections': 0,
    'nb_connections_limit': 100,
    'total_downloaded': hasMetadata ? _size : 0,
    'total_downloaded_session': 0,
    'total_uploaded': 0,
    'total_uploaded_session': 0,
    'dl_speed': dlSpeed,
    'dl_speed_avg': 0,
    'up_speed': upSpeed,
    'up_speed_avg': 0,
    'dl_limit': -1,
    'up_limit': -1,
    'total_wasted': 0,
    'seeds': 0,
    'seeds_total': 212,
    'peers': 0,
    'peers_total': 9,
    'share_ratio': 0,
    if (since50) 'popularity': 0,
    'reannounce': 0,
    // A torrent with no metadata has no size and no pieces to count.
    'total_size': hasMetadata ? _size : -1,
    'pieces_num': hasMetadata ? 3016 : -1,
    'piece_size': hasMetadata ? 262144 : -1,
    'pieces_have': hasMetadata ? 3016 : 0,
    'created_by': '',
    // What the torrent object answers, which is false while it has no
    // metadata, private tracker or not.
    if (since46) 'is_private': hasMetadata && private,
    if (since50) 'private': hasMetadata ? private : null,
    'addition_date': 1790000000,
    'last_seen': hasMetadata ? 1790003600 : -1,
    'completion_date': hasMetadata ? 1790003600 : -1,
    'creation_date': hasMetadata ? 1789000000 : -1,
    'save_path': '/data/torrents',
    if (since46) 'download_path': '',
    'comment': '',
    if (since50) 'has_metadata': hasMetadata,
  };
}
