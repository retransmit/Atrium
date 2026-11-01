const asset = (path) => `${import.meta.env.BASE_URL}${path.replace(/^\//, '')}`;

export const servicesList = [
  'sonarr',
  'radarr',
  'prowlarr',
  'bazarr',
  'seerr',
  'tautulli',
  'jellyfin',
  'emby',
  'plex',
  'qbittorrent',
  'deluge',
  'transmission',
  'rtorrent',
  'aria2',
  'tracearr',
  'sabnzbd',
  'nzbget',
  'glances',
  'speedtest-tracker',
  'cleanuparr',
  'slskd'
];

export const servicesData = {
  sonarr: {
    name: 'Sonarr',
    category: 'The *arr Stack',
    icon: asset('assets/service_icons/sonarr.png'),
    screenshots: [
      asset('assets/service_previews/sonarr/sonarr_1.png'),
      asset('assets/service_previews/sonarr/sonarr_2.png'),
      asset('assets/service_previews/sonarr/sonarr_3.png'),
      asset('assets/service_previews/sonarr/sonarr_4.png')
    ],
    description: 'Full control over your automated TV series collections. Inspect library status, edit series configuration, and search for episodes on the fly.',
    features: [
      'Interactive Manual Release Search & Grab',
      'Upcoming Airings Calendar Grid',
      'Granular Quality & Root Folder Profiles',
      'Detailed Episode Monitoring & History'
    ]
  },
  radarr: {
    name: 'Radarr',
    category: 'The *arr Stack',
    icon: asset('assets/service_icons/radarr.png'),
    screenshots: [
      asset('assets/service_previews/radarr/radarr_1.png'),
      asset('assets/service_previews/radarr/radarr_2.png'),
      asset('assets/service_previews/radarr/radarr_3.png'),
      asset('assets/service_previews/radarr/radarr_4.png')
    ],
    description: 'Manage your automated movie collections directly from your phone. Add new theatrical releases, inspect availability, and oversee active grabs.',
    features: [
      'Global Movie Release Calendar',
      'Manual Movie Search & Custom Grabbing',
      'Cast, Crew & Cinema Metadata Explorer',
      'Quick Availability Filtering & Status Dots'
    ]
  },
  prowlarr: {
    name: 'Prowlarr',
    category: 'The *arr Stack',
    icon: asset('assets/service_icons/prowlarr.png'),
    screenshots: [
      asset('assets/service_previews/prowlarr/prowlarr_1.png'),
      asset('assets/service_previews/prowlarr/prowlarr_2.png'),
      asset('assets/service_previews/prowlarr/prowlarr_3.png'),
      asset('assets/service_previews/prowlarr/prowlarr_4.png')
    ],
    description: 'Your indexer synchronization hub. Perform manual cross-indexer searches, grab results to any client, and check indexer health.',
    features: [
      'Add & Configure Public or Private Indexers',
      'Manual Universal Cross-Indexer Search',
      'Instant Grab to Download Clients',
      'Real-time System Status & Grab History'
    ]
  },
  bazarr: {
    name: 'Bazarr',
    category: 'The *arr Stack',
    icon: asset('assets/service_icons/bazarr.png'),
    screenshots: [
      asset('assets/service_previews/bazarr/bazarr_1.jpeg'),
      asset('assets/service_previews/bazarr/bazarr_2.jpeg'),
      asset('assets/service_previews/bazarr/bazarr_3.jpeg'),
      asset('assets/service_previews/bazarr/bazarr_4.jpeg'),
      asset('assets/service_previews/bazarr/bazarr_5.jpeg')
    ],
    description: 'The companion subtitle manager for Sonarr and Radarr. Ensure every series and movie has perfectly synced audio and subtitle files.',
    features: [
      'Inspect Wanted Subtitle Queues',
      'Trigger Manual Subtitle Searches & Syncing',
      'Review Language & Audio Profiles',
      'Provider Statistics & Custom Adjustments'
    ]
  },
  seerr: {
    name: 'Seerr',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/seerr.png'),
    screenshots: [
      asset('assets/service_previews/seerr/seerr_1.png'),
      asset('assets/service_previews/seerr/seerr_2.png'),
      asset('assets/service_previews/seerr/seerr_3.png')
    ],
    description: 'The premier media discovery and request management hub. Discover trending movies and TV series, review issue reports, and moderate user requests with ease.',
    features: [
      'Discover Trending Movies & TV Shows',
      'One-Tap Media Requesting',
      'Approve, Decline & Retry User Requests',
      'Universal Search Across All Libraries'
    ]
  },
  tautulli: {
    name: 'Tautulli',
    category: 'Media Servers',
    icon: asset('assets/service_icons/tautulli.png'),
    screenshots: [
      asset('assets/service_previews/tautulli/tautulli_1.png'),
      asset('assets/service_previews/tautulli/tautulli_2.png'),
      asset('assets/service_previews/tautulli/tautulli_3.png')
    ],
    description: 'Deep analytics and supervision for your Plex server. Monitor active streaming sessions in real-time and review historical trends.',
    features: [
      '30-Day Streaming Activity Graphs',
      'Granular User & Media Play History',
      'Real-Time Active Stream Inspection',
      'Remote Active Stream Termination'
    ]
  },
  jellyfin: {
    name: 'Jellyfin',
    category: 'Media Servers',
    icon: asset('assets/service_icons/jellyfin.png'),
    screenshots: [
      asset('assets/service_previews/jellyfin/jellyfin_1.png'),
      asset('assets/service_previews/jellyfin/jellyfin_2.png'),
      asset('assets/service_previews/jellyfin/jellyfin_3.png')
    ],
    description: 'The premier free software media server. Experience beautiful poster grids, live stream inspection, and smooth library navigation.',
    features: [
      'Beautiful Material 3 Poster Grids',
      'Active Media Session Supervision',
      'Remote Play Capabilities',
      'Comprehensive Video & Audio Catalog Support'
    ]
  },
  emby: {
    name: 'Emby',
    category: 'Media Servers',
    icon: asset('assets/service_icons/emby.png'),
    screenshots: [
      asset('assets/service_previews/emby/emby_1.png'),
      asset('assets/service_previews/emby/emby_2.png'),
      asset('assets/service_previews/emby/emby_3.png'),
      asset('assets/service_previews/emby/emby_4.png'),
      asset('assets/service_previews/emby/emby_5.png')
    ],
    description: 'Bring all your media together in one clean interface. Oversee connected users, manage libraries, and trigger playback.',
    features: [
      'Responsive Library Navigation & Folders',
      'Live Active Session Supervision',
      'Native Remote Control Interaction',
      'Detailed Media Metadata Explorer'
    ]
  },
  plex: {
    name: 'Plex',
    category: 'Media Servers',
    icon: asset('assets/service_icons/plex.png'),
    screenshots: [
      asset('assets/service_previews/plex/plex_1.png'),
      asset('assets/service_previews/plex/plex_2.png')
    ],
    description: 'Connect to your Plex Media Servers seamlessly. Explore libraries, filter by tags or genres, and monitor active transcoding sessions.',
    features: [
      'Explore Multi-Library Movie & TV Catalogs',
      'Granular Tag, Genre & Actor Filtering',
      'Now-Playing Remote Media Controller',
      'Music & Soundtrack Collection Support'
    ]
  },
  qbittorrent: {
    name: 'qBittorrent',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/qbittorrent.png'),
    screenshots: [
      asset('assets/service_previews/qbittorrent/qbittorrent_1.png'),
      asset('assets/service_previews/qbittorrent/qbittorrent_2.png')
    ],
    description: 'Powerful remote control over your torrent queues. Track transfer speeds, toggle individual file priorities, and inspect peer details.',
    features: [
      'Real-Time Torrent List & Speed Gauges',
      'Granular Per-File Priority Toggling',
      'Detailed Tracker & Peer Diagnostic Views',
      'Add, Pause, Resume & Categorize Torrents'
    ]
  },
  deluge: {
    name: 'Deluge',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/deluge.png'),
    screenshots: [
      asset('assets/service_previews/deluge/deluge_1.png'),
      asset('assets/service_previews/deluge/deluge_2.png')
    ],
    description: 'Lightweight and powerful daemon control. Keep tabs on active transfers, adjust bandwidth limits, and manage trackers on the move.',
    features: [
      'Live Transfer Queue & Speed Indicators',
      'Start, Stop, Delete & Queue Reordering',
      'Per-Torrent Bandwidth Throttling',
      'Granular File, Peer & Tracker Inspection'
    ]
  },
  transmission: {
    name: 'Transmission',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/transmission.png'),
    screenshots: [
      asset('assets/service_previews/transmission/transmission_1.png'),
      asset('assets/service_previews/transmission/transmission_2.png')
    ],
    description: 'Clean, native interface for Transmission daemons. Easily supervise your ongoing downloads, seeding ratios, and speed restrictions.',
    features: [
      'Live Seeding Ratio & Speed Supervision',
      'Quick Speed Limit & Alternate Mode Toggle',
      'Add Torrent by Magnet Link or File',
      'Individual File Selection & Priority Control'
    ]
  },
  rtorrent: {
    name: 'rTorrent',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/rutorrent.png'),
    screenshots: [
      asset('assets/service_previews/rtorrent/rtorrent_1.png'),
      asset('assets/service_previews/rtorrent/rtorrent_2.png')
    ],
    description: 'Direct communication with your rTorrent / ruTorrent server. Supervise massive torrent swarms with rapid polling and low overhead.',
    features: [
      'High-Performance Torrent Queue Polling',
      'Real-Time Transfer Rates & Peer Ratios',
      'Granular Pause, Resume & Remove Actions',
      'Detailed Tracker Status & Hash Checks'
    ]
  },
  aria2: {
    name: 'aria2',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/aria2.png'),
    screenshots: [
      asset('assets/service_previews/aria2/aria2_1.png'),
      asset('assets/service_previews/aria2/aria2_2.png'),
      asset('assets/service_previews/aria2/aria2_3.png'),
      asset('assets/service_previews/aria2/aria2_4.png')
    ],
    description: 'Lightweight multi-protocol download utility client. Supervise active tasks with real-time throughput telemetry, adjust individual speed limits, inject live mirrors, and manage global daemon options.',
    features: [
      'Unified Transfers Hub with Real-Time Speed Telemetry',
      'Multi-Field Sorting & Live Search Filtering',
      'Batch Multi-Select Pause, Resume & Remove Actions',
      'Per-Task Speed Limits & Live Mirror Injection',
      'Full Daemon Settings Editor & System Diagnostics'
    ]
  },
  tracearr: {
    name: 'Tracearr',
    category: 'Media Servers',
    icon: asset('assets/service_icons/tracearr.png'),
    screenshots: [
      asset('assets/service_previews/tracearr/tracearr_1.png'),
      asset('assets/service_previews/tracearr/tracearr_2.png'),
      asset('assets/service_previews/tracearr/tracearr_3.png'),
      asset('assets/service_previews/tracearr/tracearr_4.png'),
      asset('assets/service_previews/tracearr/tracearr_5.png')
    ],
    description: 'Cross-platform media analytics. Aggregate live streaming sessions across Plex, Jellyfin, and Emby into a unified geolocation dashboard.',
    features: [
      'Unified Live Streams across Plex, Emby & Jellyfin',
      'Interactive Geolocation Streamer Map',
      'Comprehensive Watch & Library Statistics',
      'Aggregated Cross-Platform Play History'
    ]
  },
  sabnzbd: {
    name: 'SABnzbd',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/sabnzbd.png'),
    screenshots: [],
    description: 'Complete Usenet newsreader automation. Control download queues, assign post-processing scripts, and manage categories effortlessly.',
    features: [
      'Usenet Queue Control with Instant Reordering',
      'Pause, Resume & Priority Adjustments',
      'Post-Processing Script & Category Routing',
      'Download History Review & Instant Retry'
    ]
  },
  nzbget: {
    name: 'NZBGet',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/nzbget.png'),
    screenshots: [],
    description: 'Ultra-fast Usenet daemon controller. Supervise download speed, manage active jobs, inspect server health, and organize completed archives.',
    features: [
      'Real-Time NZB Queue & Bandwidth Limiter',
      'Granular Job Priority & Category Management',
      'Live Usenet Server Health & Logging Diagnostics',
      'Clean Download History & Archive Actions'
    ]
  },
  glances: {
    name: 'Glances',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/glances.png'),
    screenshots: [
      asset('assets/service_previews/glances/glances_1.png'),
      asset('assets/service_previews/glances/glances_2.png')
    ],
    description: 'Live cross-platform system monitoring. Keep an eye on server CPU load, RAM utilization, network traffic, and disk storage usage.',
    features: [
      'Real-Time CPU & Memory Utilization Gauges',
      'Network I/O Throughput & Traffic Rates',
      'Storage Disk Volume Capacity Inspection',
      'Temperature Sensors & System Uptime'
    ]
  },
  'speedtest-tracker': {
    name: 'Speedtest Tracker',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/speedtest-tracker.png'),
    screenshots: [
      asset('assets/service_previews/speedtest/speedtest_1.png')
    ],
    description: 'Continuous network performance logging. Track historical download and upload trends, and trigger remote speed tests from anywhere.',
    features: [
      'Trigger Remote Speed Tests Instantly',
      'Historical Download & Upload Charts',
      'Ping & Jitter Variance Logging',
      'ISP Performance Diagnostic Summaries'
    ]
  },
  cleanuparr: {
    name: 'Cleanuparr',
    category: 'The *arr Stack',
    icon: asset('assets/service_icons/cleanuparr.png'),
    screenshots: [
      asset('assets/service_previews/cleanuparr/cleanuparr_1.png'),
      asset('assets/service_previews/cleanuparr/cleanuparr_2.png'),
      asset('assets/service_previews/cleanuparr/cleanuparr_3.png'),
      asset('assets/service_previews/cleanuparr/cleanuparr_4.png')
    ],
    description: 'Automated download cleaner and malware blocker for the Servarr ecosystem and download clients. Quarantines suspicious payloads, enforces item strikes, and purges orphaned items.',
    features: [
      'Automated Malware & Unwanted File Blocking',
      'Active Download Strikes Ledger & Resets',
      'Comprehensive Security & Operation Audit Feed',
      'Background Cleaner Jobs with On-Demand Runs'
    ]
  },
  slskd: {
    name: 'slskd',
    category: 'Downloads & Utilities',
    icon: asset('assets/service_icons/slskd.png'),
    screenshots: [
      asset('assets/service_previews/slskd/slskd_1.png'),
      asset('assets/service_previews/slskd/slskd_2.png'),
      asset('assets/service_previews/slskd/slskd_3.png'),
      asset('assets/service_previews/slskd/slskd_4.png')
    ],
    description: 'Modern mobile client for the Soulseek P2P music network. Search releases by album, browse shared peer collections, exchange DMs, and manage upload/download queues.',
    features: [
      'Concurrent P2P Search with Album Grouping & Bitrate Filtering',
      'Hierarchical Peer Shares Navigation with Breadcrumb Traversal',
      'Unified Community Hub with Public Rooms & 1-on-1 Messages',
      'Deep Transfer Telemetry with Queue Rank & Peer Analytics'
    ]
  }
};
