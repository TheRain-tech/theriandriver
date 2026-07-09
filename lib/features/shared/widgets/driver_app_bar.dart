import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';

class DriverAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DriverAppBar({
    super.key,
    this.title,
    this.showBack = false,
    this.showLogo = true,
    this.showOnline = false,
    this.actions,
  });

  final String? title;
  final bool showBack;
  final bool showLogo;
  final bool showOnline;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title: title != null
          ? Text(title!)
          : showLogo
          ? const AppLogo(compact: true)
          : null,
      actions: [
        if (showOnline)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: DriverProfileService.instance.profile,
                builder: (context, profile, _) {
                  final isOnline =
                      profile.onlineStatus != DriverOnlineStatus.offline;
                  return StatusBadge(
                    label: isOnline ? 'Online' : 'Offline',
                    tone: isOnline ? BadgeTone.success : BadgeTone.neutral,
                  );
                },
              ),
            ),
          ),
        ...?actions,
        if (actions != null) const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}
