import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared page header — large title + muted subtitle on the left, actions (search/filter/refresh/
/// primary button, in that order by convention) on the right. Replaces the hand-rolled
/// `Row[Text(headlineSmall), Spacer, ...]` pattern that was copy-pasted with slightly different
/// spacing/typography into every screen.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppPalette.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    final actionsBlock = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    // A Row (not a Wrap) for the outer layout: a Wrap only ever sizes to its own content, so inside
    // a start-aligned Column it would hug the title+actions' combined width instead of stretching
    // edge-to-edge — leaving the actions stranded right next to the title instead of at the far
    // right. Row always fills the width its parent gives it, so `actionsBlock` reliably lands at
    // the trailing edge; the title's Expanded lets it wrap/ellipsize if the actions ever crowd it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        actionsBlock,
      ],
    );
  }
}
