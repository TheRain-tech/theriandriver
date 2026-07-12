import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.current,
    this.total = 5,
    this.labels,
    this.onStepTap,
  });

  final int current;
  final int total;
  final List<String>? labels;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final step = index + 1;
        final done = step < current;
        final active = step == current;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: step <= current
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onStepTap == null ? null : () => onStepTap!(step),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: done || active
                            ? AppColors.primary
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done || active
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                '$step',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (index < total - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: step < current
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              if (labels != null) ...[
                const SizedBox(height: 7),
                Text(
                  labels![index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? AppColors.primary : AppColors.slate,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
