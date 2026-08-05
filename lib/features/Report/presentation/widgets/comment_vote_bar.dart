import 'package:flutter/material.dart';

import '../../domain/models/comment_model.dart';

class CommentVoteBar extends StatelessWidget {
  const CommentVoteBar({
    super.key,
    required this.comment,
    required this.onVote,
    this.enabled = true,
  });

  final CommentModel comment;

  final ValueChanged<String> onVote;

  final bool enabled;

  static const _upColour = Color(0xFF1A73E8);
  static const _downColour = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _arrow(
            icon: Icons.arrow_upward,
            count: comment.upvoteCount,
            active: comment.userVoteType == 'up',
            colour: _upColour,
            tooltip: 'Helpful',
            onTap: () => onVote('up'),
          ),
          const SizedBox(width: 4),
          _arrow(
            icon: Icons.arrow_downward,
            count: comment.downvoteCount,
            active: comment.userVoteType == 'down',
            colour: _downColour,
            tooltip: 'Not helpful',
            onTap: () => onVote('down'),
          ),
        ],
      ),
    );
  }

  Widget _arrow({
    required IconData icon,
    required int count,
    required bool active,
    required Color colour,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final shade = active ? colour : Colors.grey[600];

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: shade),
              
              if (count > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: shade,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
