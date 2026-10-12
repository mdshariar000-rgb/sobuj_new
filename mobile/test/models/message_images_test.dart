import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group_message.dart';
import 'package:shobuj_mobile/models/swap_message.dart';

Map<String, dynamic> _json(Map<String, dynamic> images) => {
  'id': 1,
  'swap_offer_id': 1,
  'group_id': 1,
  'message_type': 'text',
  'body': null,
  'sender': null,
  'created_at': '2026-09-30T10:00:00Z',
  ...images,
};

void main() {
  test('reads every photo from image_urls', () {
    final message = SwapMessage.fromJson(
      _json({
        'image_url': 'https://x/a.jpg',
        'image_urls': ['https://x/a.jpg', 'https://x/b.jpg'],
      }),
    );

    expect(message.imageUrls, ['https://x/a.jpg', 'https://x/b.jpg']);
    expect(message.hasImages, isTrue);
  });

  test('falls back to the single image_url from an older backend', () {
    final message = GroupMessage.fromJson(
      _json({'image_url': 'https://x/a.jpg'}),
    );

    expect(message.imageUrls, ['https://x/a.jpg']);
  });

  test('a text-only message has no photos', () {
    final message = GroupMessage.fromJson(
      _json({'image_url': null, 'image_urls': <String>[]}),
    );

    expect(message.imageUrls, isEmpty);
    expect(message.hasImages, isFalse);
  });

  test('reads the quoted message of a reply', () {
    final message = SwapMessage.fromJson(
      _json({
        'reply_to_id': 4,
        'reply_to': {
          'id': 4,
          'body': null,
          'sender_name': 'Elena',
          'image_url': 'https://x/a.jpg',
          'image_count': 3,
        },
      }),
    );

    expect(message.replyToId, 4);
    expect(message.replyTo?.senderName, 'Elena');
    expect(message.replyTo?.summary, '📷 3 photos');
  });

  test('a reply to a deleted message keeps its id but has no quote', () {
    final message = GroupMessage.fromJson(
      _json({'reply_to_id': 4, 'reply_to': null}),
    );

    expect(message.replyToId, 4);
    expect(message.replyTo, isNull);
  });

  test('accepts reply_to_id echoed back as a string', () {
    final message = GroupMessage.fromJson(
      _json({
        'reply_to_id': '69',
        'reply_to': {'id': 69, 'body': 'Hi', 'sender_name': 'Elena'},
      }),
    );

    expect(message.replyToId, 69);
    expect(message.replyTo?.body, 'Hi');
  });
}
