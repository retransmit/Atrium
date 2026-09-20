import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/ombi_fixtures.dart';

void main() {
  group('requireData', () {
    test('hands back the data of a good answer', () {
      final ApiResponse<RequestCountModel> ok =
          ApiResponse<RequestCountModel>.success(
        RequestCountModel.fromJson(countsJson),
        statusCode: 200,
      );

      expect(requireData(ok, 'Loading').pending, 2);
    });

    test('turns a failure into an exception carrying the status', () {
      const ApiResponse<RequestCountModel> refused =
          ApiResponse<RequestCountModel>.error(
        OmbiError(message: 'Unauthorized'),
        statusCode: 401,
      );

      expect(
        () => requireData(refused, 'Loading'),
        throwsA(
          isA<OmbiException>()
              .having((OmbiException e) => e.statusCode, 'status', 401),
        ),
      );
    });
  });

  group('requireDone', () {
    test('passes a result without an error', () {
      requireDone(
        ApiResponse<RequestEngineResult>.success(
          RequestEngineResult.fromJson(engineOk()),
          statusCode: 200,
        ),
        'Approving',
      );
    });

    test("an error inside a 200 is still a failure, in Ombi's words", () {
      expect(
        () => requireDone(
          ApiResponse<RequestEngineResult>.success(
            RequestEngineResult.fromJson(
              engineError('This has already been requested'),
            ),
            statusCode: 200,
          ),
          'Requesting',
        ),
        throwsA(
          isA<OmbiException>().having(
            (OmbiException e) => e.message,
            'message',
            'This has already been requested',
          ),
        ),
      );
    });
  });

  group('describeOmbiFailure', () {
    test('a refused key says where the key lives', () {
      expect(
        describeOmbiFailure(const OmbiException('x', statusCode: 401)),
        'Ombi refused the API key. It is under Settings, Ombi.',
      );
    });

    test('Ombi saying no is reported in its own words', () {
      expect(
        describeOmbiFailure(
          const OmbiException('Already requested', statusCode: 200),
        ),
        'Already requested',
      );
    });

    test('a failed search points at the movie database', () {
      expect(
        describeOmbiFailure(
          const OmbiException('boom', statusCode: 500),
          lookup: OmbiLookup.search,
        ),
        'Ombi could not search right now. It could not reach its movie '
        'database. Try again.',
      );
    });

    test('a failed Discover list points at the movie database too', () {
      expect(
        describeOmbiFailure(
          const OmbiException('boom', statusCode: 500),
          lookup: OmbiLookup.list,
        ),
        'Ombi could not load this list right now. It could not reach its '
        'movie database.',
      );
    });

    test('so does a title Ombi could not look up', () {
      expect(
        describeOmbiFailure(
          const OmbiException('boom', statusCode: 500),
          lookup: OmbiLookup.title,
        ),
        'Ombi could not look this title up right now. It could not reach '
        'its movie database.',
      );
    });

    test('a refused key is still a refused key during a lookup', () {
      expect(
        describeOmbiFailure(
          const OmbiException('x', statusCode: 401),
          lookup: OmbiLookup.title,
        ),
        'Ombi refused the API key. It is under Settings, Ombi.',
      );
    });

    test('anything else names the status', () {
      expect(
        describeOmbiFailure(const OmbiException('boom', statusCode: 502)),
        'Ombi answered HTTP 502.',
      );
    });

    test('no answer at all says Ombi could not be reached', () {
      expect(
        describeOmbiFailure(const OmbiException('timeout')),
        'Ombi could not be reached.',
      );
      expect(
        describeOmbiFailure(StateError('x')),
        'Ombi could not be reached.',
      );
    });
  });
}
