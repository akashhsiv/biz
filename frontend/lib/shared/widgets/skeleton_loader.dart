import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A single shimmering placeholder block. Building block for table/card skeletons — a screen mid-
/// load shows the shape of its content instead of just a spinner floating in empty space.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({super.key, this.width = double.infinity, this.height = 14, this.borderRadius});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(AppPalette.border, AppPalette.surface, _controller.value),
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Skeleton rows shaped like an [AppListCard] table body — same column-count/flex feel as the real
/// rows so the loading state doesn't visually jump once data arrives.
class SkeletonTableRows extends StatelessWidget {
  final int columns;
  final int rowCount;

  const SkeletonTableRows({super.key, this.columns = 4, this.rowCount = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < rowCount; r++) ...[
          if (r > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 16),
                  Expanded(child: SkeletonBox(width: c == 0 ? 80 : double.infinity)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
