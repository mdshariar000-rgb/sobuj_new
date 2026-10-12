import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/message_reaction.dart';

void main() {
  const heart = MessageReaction(emoji: '❤️', userIds: [2]);
  const thumbs = MessageReaction(emoji: '👍', userIds: [1, 3]);

  List<String> flat(List<MessageReaction> r) => [
    for (final x in r) '${x.emoji}:${x.userIds.join(',')}',
  ];

  test('adding a new emoji appends it', () {
    expect(flat(toggleReaction([heart], userId: 5, emoji: '😂')), [
      '❤️:2',
      '😂:5',
    ]);
  });

  test('joining an existing emoji adds to its count', () {
    expect(flat(toggleReaction([heart], userId: 5, emoji: '❤️')), ['❤️:2,5']);
  });

  test('picking another emoji moves the user, dropping emptied ones', () {
    expect(flat(toggleReaction([heart, thumbs], userId: 1, emoji: '❤️')), [
      '❤️:2,1',
      '👍:3',
    ]);
    expect(flat(toggleReaction([heart], userId: 2, emoji: '👍')), ['👍:2']);
  });

  test('tapping your current emoji removes it', () {
    expect(flat(toggleReaction([heart, thumbs], userId: 2, emoji: '❤️')), [
      '👍:1,3',
    ]);
  });

  test('myReaction finds the user\'s emoji', () {
    expect(myReaction([heart, thumbs], 3), '👍');
    expect(myReaction([heart, thumbs], 9), isNull);
    expect(myReaction([heart], null), isNull);
  });

  test('parses the API shape, including string ids', () {
    final parsed = MessageReaction.listFromJson([
      {
        'emoji': '🙏',
        'count': 2,
        'user_ids': [4, '7'],
      },
    ]);
    expect(parsed.single.emoji, '🙏');
    expect(parsed.single.userIds, [4, 7]);
    expect(parsed.single.count, 2);
  });
}
