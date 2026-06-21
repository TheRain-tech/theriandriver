import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class RatingStars extends StatefulWidget {
  const RatingStars({
    super.key,
    this.initialRating = 5,
    this.onChanged,
    this.size = 38,
  });
  final int initialRating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {
  late int rating = widget.initialRating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: List.generate(5, (index) {
      final value = index + 1;
      return IconButton(
        onPressed: () {
          setState(() => rating = value);
          widget.onChanged?.call(value);
        },
        iconSize: widget.size,
        icon: Icon(
          value <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: value <= rating ? AppColors.warning : AppColors.border,
        ),
      );
    }),
  );
}
