import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../support/screens/help_center_screen.dart';

class DriverAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DriverAppBar({
    super.key,
    this.title,
    this.showBack = false,
    this.showLogo = true,
    this.showOnline = false,
    this.showFullHeader = false,
    this.actions,
  });

  final String? title;
  final bool showBack;
  final bool showLogo;
  final bool showOnline;
  final bool showFullHeader;
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(showFullHeader ? 60 : 68);

  @override
  Widget build(BuildContext context) {
    if (showFullHeader) return _buildFullHeader(context);
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
                    tone: isOnline ? BadgeTone.success : BadgeTone.danger,
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

  Widget _buildFullHeader(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      titleSpacing: 0,
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.profile),
              icon: const Icon(
                Icons.account_circle_rounded,
                color: AppColors.navy,
              ),
            ),
            const AppLogo(compact: true),
            ValueListenableBuilder(
              valueListenable: DriverProfileService.instance.profile,
              builder: (context, profile, _) {
                final isOnline =
                    profile.onlineStatus != DriverOnlineStatus.offline;
                return StatusBadge(
                  label: isOnline ? 'Online' : 'Offline',
                  tone: isOnline ? BadgeTone.success : BadgeTone.danger,
                );
              },
            ),
            _SosButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpCenterScreen(),
                ),
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD32F2F),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: const SizedBox(
          width: 48,
          height: 32,
          child: Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
