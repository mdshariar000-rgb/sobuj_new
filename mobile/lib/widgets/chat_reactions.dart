import 'package:flutter/material.dart';

import '../models/message_reaction.dart';
import '../theme/app_colors.dart';

/// The reactions under a chat bubble, one chip per emoji with its count.
/// The signed-in user's own reaction is highlighted; tapping a chip toggles
/// that emoji for them.
class ReactionChips extends StatelessWidget {
  const ReactionChips({
    super.key,
    required this.reactions,
    required this.myUserId,
    required this.onTap,
  });

  final List<MessageReaction> reactions;
  final int? myUserId;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final reaction in reactions)
            _Chip(
              reaction: reaction,
              isMine: myUserId != null && reaction.userIds.contains(myUserId),
              onTap: onTap == null ? null : () => onTap!(reaction.emoji),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.reaction, required this.isMine, this.onTap});

  final MessageReaction reaction;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('reaction-chip-${reaction.emoji}'),
      color: isMine
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      shape: StadiumBorder(
        side: BorderSide(
          color: isMine ? AppColors.primary : Colors.transparent,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            reaction.count > 1
                ? '${reaction.emoji} ${reaction.count}'
                : reaction.emoji,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isMine ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The row of quick reactions at the top of a message's long-press sheet.
/// [current] (the user's existing reaction) is ringed; picking it again
/// removes it.
class ReactionPickerRow extends StatelessWidget {
  const ReactionPickerRow({
    super.key,
    required this.current,
    required this.onPick,
  });

  final String? current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in reactionEmojis)
            InkResponse(
              key: Key('react-$emoji'),
              onTap: () => onPick(emoji),
              radius: 26,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emoji == current
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : null,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    );
  }
}
