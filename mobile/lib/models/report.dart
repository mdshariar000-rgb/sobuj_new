/// What kind of thing is being reported — [wireValue] is the backend's
/// `target_type` slug (see App\Enums\ReportTargetType).
enum ReportTarget {
  post('post', 'post'),
  comment('comment', 'comment'),
  listing('listing', 'listing'),
  event('event', 'event'),
  group('group', 'group'),
  user('user', 'user'),
  groupMessage('group_message', 'message'),
  message('message', 'message');

  const ReportTarget(this.wireValue, this.noun);

  final String wireValue;

  /// Lowercase noun used in UI copy ("Report this post").
  final String noun;
}

/// Mirrors App\Enums\ReportReason.
enum ReportReason {
  spam('spam', 'Spam'),
  inappropriate('inappropriate', 'Inappropriate or offensive'),
  harassment('harassment', 'Harassment or hate'),
  misleading('misleading', 'Misleading or scam'),
  illegal('illegal', 'Illegal or banned species'),
  other('other', 'Other');

  const ReportReason(this.wireValue, this.label);

  final String wireValue;
  final String label;
}
