import 'models/seerr_request.dart';

/// The chips over the Requests tab. Each one keeps the requests of one
/// request status (1 pending, 2 approved, 3 declined, 4 failed,
/// 5 completed), as Seerr's own filters do: a request moves from approved
/// to completed once its media is available. [all] keeps every one.
enum SeerrRequestFilter {
  all('All', 'No requests', 'No media requests yet.'),
  pending('Pending', 'No pending requests', 'Nothing is waiting for approval.'),
  approved('Approved', 'No approved requests', 'No request has been approved.'),
  completed(
    'Completed',
    'No completed requests',
    'Requests show here once their media is available.',
  ),
  declined('Declined', 'No declined requests', 'No request has been declined.'),
  failed(
    'Failed',
    'No failed requests',
    'Every approved request reached Sonarr or Radarr.',
  );

  const SeerrRequestFilter(this.label, this.emptyTitle, this.emptyMessage);

  final String label;
  final String emptyTitle;
  final String emptyMessage;

  /// Whether [request] shows under this chip.
  bool keeps(SeerrRequest request) => switch (this) {
        SeerrRequestFilter.all => true,
        SeerrRequestFilter.pending => request.status == 1,
        SeerrRequestFilter.approved => request.status == 2,
        SeerrRequestFilter.declined => request.status == 3,
        SeerrRequestFilter.completed => request.status == 5,
        SeerrRequestFilter.failed => request.status == 4,
      };

  /// [requests] cut down to this chip, in the order they came.
  List<SeerrRequest> apply(List<SeerrRequest> requests) => this == all
      ? requests
      : <SeerrRequest>[
          for (final SeerrRequest r in requests)
            if (keeps(r)) r,
        ];
}
