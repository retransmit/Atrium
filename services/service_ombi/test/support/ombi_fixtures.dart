/// Payloads shaped the way Ombi v4.53 sends them.
///
/// Field names come from Ombi's OpenAPI spec and the payloads checked against
/// a live server; the live run swaps in captured bodies with personal details
/// removed. Nothing here is a real user.
library;

const Map<String, dynamic> aliceJson = <String, dynamic>{
  'id': 'user-1',
  'userName': 'alice',
  'alias': null,
  'userAlias': 'alice',
  'userType': 1,
};

Map<String, dynamic> movieRequestJson({
  int id = 11,
  bool approved = false,
  bool available = false,
  bool denied = false,
  String? deniedReason,
  bool has4KRequest = false,
  String requestedDate = '2026-09-18T10:15:00',
}) =>
    <String, dynamic>{
      'id': id,
      'title': 'Arrival',
      'has4KRequest': has4KRequest,
      'theMovieDbId': 329865,
      'posterPath': '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
      'background': '/yIZ1xendyqKvY3FGeeUYUd5X9Mm.jpg',
      'overview': 'A linguist is recruited to talk to visitors.',
      'releaseDate': '2016-11-10T00:00:00',
      'requestedDate': requestedDate,
      'approved': approved,
      'available': available,
      'denied': denied,
      'deniedReason': deniedReason,
      'requestedByAlias': null,
      'requestedUser': aliceJson,
      'canApprove': true,
      // Enums arrive as integers, not strings.
      'requestType': 1,
      'source': 0,
    };

/// [episodesIn] says, episode by episode, which requested episodes of
/// season 1 Ombi has found. [moreSeasons] does the same for further seasons,
/// keyed by season number.
Map<String, dynamic> childRequestJson({
  int id = 21,
  bool approved = false,
  bool available = false,
  bool denied = false,
  List<bool> episodesIn = const <bool>[],
  Map<int, List<bool>> moreSeasons = const <int, List<bool>>{},
  String requestedDate = '2026-09-17T08:00:00',
}) =>
    <String, dynamic>{
      'id': id,
      'title': null,
      'approved': approved,
      'available': available,
      'denied': denied,
      'deniedReason': null,
      'requestedDate': requestedDate,
      'requestedByAlias': null,
      'requestedUser': aliceJson,
      'releaseYear': '2022-02-18T00:00:00',
      'requestType': 0,
      'seriesType': 0,
      'parentRequest': <String, dynamic>{
        'id': 3,
        'tvDbId': 371980,
        // The show's TMDB id, which is what its title page is looked up by.
        'externalProviderId': 95396,
        'title': 'Severance',
        'overview': 'Mark leads a team of office workers.',
        'posterPath': '/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
        'background': '/npD65vPa4vvn1ZHpp3o05A5vdKT.jpg',
        'releaseDate': '2022-02-18T00:00:00',
        'status': 'Returning Series',
        'totalSeasons': 2,
      },
      'seasonRequests': <Object>[
        for (final MapEntry<int, List<bool>> season in <int, List<bool>>{
          if (episodesIn.isNotEmpty) 1: episodesIn,
          ...moreSeasons,
        }.entries)
          <String, dynamic>{
            'id': 6 + season.key,
            'seasonNumber': season.key,
            'childRequestId': id,
            'seasonAvailable': false,
            'episodes': <Object>[
              for (int i = 0; i < season.value.length; i++)
                <String, dynamic>{
                  'id': season.key * 100 + i,
                  'episodeNumber': i + 1,
                  'title': 'Episode ${i + 1}',
                  'requested': true,
                  'approved': approved,
                  'available': season.value[i],
                  'denied': false,
                },
            ],
          },
      ],
    };

Map<String, dynamic> albumRequestJson({int id = 31}) => <String, dynamic>{
      'id': id,
      'title': 'Blue Train',
      'artistName': 'John Coltrane',
      'cover': 'https://coverartarchive.org/release/abc/front-250.jpg',
      'releaseDate': '1957-01-01T00:00:00',
      'requestedDate': '2026-09-16T12:00:00',
      'approved': true,
      'available': false,
      'denied': false,
      'deniedReason': null,
      'requestedByAlias': null,
      'requestedUser': aliceJson,
    };

/// A v2 list response.
Map<String, dynamic> pageJson(List<Map<String, dynamic>> items, {int? total}) =>
    <String, dynamic>{'collection': items, 'total': total ?? items.length};

const Map<String, dynamic> countsJson = <String, dynamic>{
  'pending': 2,
  'approved': 1,
  'available': 4,
  'denied': 1,
};

const List<Map<String, dynamic>> searchJson = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': '329865',
    'mediaType': 'movie',
    'title': 'Arrival',
    'poster': '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
    'overview': 'A linguist is recruited to talk to visitors.',
  },
  <String, dynamic>{
    'id': '95396',
    'mediaType': 'tv',
    'title': 'Severance',
    'poster': '/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
    'overview': 'Mark leads a team of office workers.',
  },
  <String, dynamic>{
    'id': '9273',
    'mediaType': 'person',
    'title': 'Amy Adams',
    'poster': null,
    'overview': null,
  },
];

Map<String, dynamic> movieDetailJson({
  bool requested = false,
  bool approved = false,
  bool available = false,
  bool denied = false,
  String? deniedReason,
}) =>
    <String, dynamic>{
      'id': 329865,
      'theMovieDbId': '329865',
      'title': 'Arrival',
      'tagline': 'Why are they here?',
      'overview': 'A linguist is recruited to talk to visitors.',
      'posterPath': '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
      'backdropPath': '/yIZ1xendyqKvY3FGeeUYUd5X9Mm.jpg',
      'releaseDate': '2016-11-10T00:00:00Z',
      'runtime': 116,
      'voteAverage': 7.6,
      'status': 'Released',
      'genres': <Object>[
        <String, dynamic>{'id': 18, 'name': 'Drama'},
        <String, dynamic>{'id': 878, 'name': 'Science Fiction'},
      ],
      'requested': requested,
      'approved': approved,
      'available': available,
      'denied': denied,
      'deniedReason': deniedReason,
    };

Map<String, dynamic> tvDetailJson({
  bool requested = false,
  bool partlyAvailable = false,
  bool fullyAvailable = false,
}) =>
    <String, dynamic>{
      'id': 95396,
      'theMovieDbId': '95396',
      'title': 'Severance',
      'tagline': 'We are all one.',
      'overview': 'Mark leads a team of office workers.',
      // A show's backdrop arrives as its banner, and its numbers as text.
      'banner': '/npD65vPa4vvn1ZHpp3o05A5vdKT.jpg',
      'images': <String, dynamic>{
        'medium': null,
        'original': '/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
      },
      'firstAired': '2022-02-18',
      'runtime': '50',
      'rating': '8.4',
      'status': 'Returning Series',
      'network': <String, dynamic>{
        'id': 2552,
        'name': 'Apple TV+',
        'country': 'US',
      },
      'genres': <Object>[
        <String, dynamic>{'id': 18, 'name': 'Drama'},
        <String, dynamic>{'id': 9648, 'name': 'Mystery'},
      ],
      'requested': requested,
      'approved': false,
      'available': false,
      'partlyAvailable': partlyAvailable,
      'fullyAvailable': fullyAvailable,
      'denied': false,
      'deniedReason': null,
      'type': 0,
    };

/// A `RequestEngineResult` that worked.
Map<String, dynamic> engineOk({int requestId = 11}) => <String, dynamic>{
      'result': true,
      'message': null,
      'isError': false,
      'errorMessage': null,
      'requestId': requestId,
    };

/// A `RequestEngineResult` Ombi sends with HTTP 200 when it said no.
Map<String, dynamic> engineError(String message) => <String, dynamic>{
      'result': false,
      'message': null,
      'isError': true,
      'errorMessage': message,
      'requestId': 0,
    };

/// A Discover movie row. Movies carry their TMDB id twice, the second time
/// as a string.
Map<String, dynamic> discoverMovieJson({
  int id = 969681,
  String title = 'Spider-Man: Brand New Day',
  bool requested = false,
  bool available = false,
}) =>
    <String, dynamic>{
      'id': id,
      'theMovieDbId': '$id',
      'title': title,
      'posterPath': '/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg',
      'backdropPath': '/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg',
      'overview': 'Peter Parker starts over.',
      'releaseDate': '2026-07-31T00:00:00',
      'voteAverage': 7.9,
      'requested': requested,
      'available': available,
      'requestId': 0,
      'type': 1,
    };

/// A Discover TV row. Here theMovieDbId is empty and the TMDB id is `id`.
/// These rows come without a first-aired date, and with the rating as text.
Map<String, dynamic> discoverShowJson({
  int id = 275102,
  String title = 'The Scandal',
  String? firstAired,
  String rating = '5.4',
}) =>
    <String, dynamic>{
      'id': id,
      'theMovieDbId': null,
      'title': title,
      'posterPath': '/pJsIzlTjmx07ilwEkl0cglrMVa1.jpg',
      'backdropPath': '/dyFTt1a9ZpFdKE96kPlE9fQvXOJ.jpg',
      'banner': '/dyFTt1a9ZpFdKE96kPlE9fQvXOJ.jpg',
      'overview': 'A drama.',
      'firstAired': firstAired,
      'rating': rating,
      'requested': false,
      'available': false,
      'requestId': 0,
      'type': 0,
    };
