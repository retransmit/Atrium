import 'generated/generated.dart';

/// A call Ombi answers by asking TheMovieDB, named by what the user was
/// doing when it failed.
enum OmbiLookup { search, list, title }

/// Says what went wrong, in words a user can act on.
///
/// Pass [lookup] for a call that goes through TheMovieDB. Ombi answers 500
/// when it cannot reach TheMovieDB, which on some networks happens often,
/// so the message points there rather than at Atrium.
String describeOmbiFailure(Object error, {OmbiLookup? lookup}) {
  final int? status = error is OmbiException ? error.statusCode : null;
  if (error is! OmbiException || status == null) {
    return 'Ombi could not be reached.';
  }
  if (status == 401 || status == 403) {
    return 'Ombi refused the API key. It is under Settings, Ombi.';
  }
  if (status >= 200 && status < 300) {
    return error.message;
  }
  if (status >= 500) {
    switch (lookup) {
      case OmbiLookup.search:
        return 'Ombi could not search right now. It could not reach its '
            'movie database. Try again.';
      case OmbiLookup.list:
        return 'Ombi could not load this list right now. It could not reach '
            'its movie database.';
      case OmbiLookup.title:
        return 'Ombi could not look this title up right now. It could not '
            'reach its movie database.';
      case null:
        break;
    }
  }
  return 'Ombi answered HTTP $status.';
}
