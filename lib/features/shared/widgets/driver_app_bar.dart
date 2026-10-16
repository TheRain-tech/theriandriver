import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../router/route_names.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';

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
    final l = DriverCopy.of(context);
    return AppBar(
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.arrow_back_rounded),
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
                    label: isOnline
                        ? l.t('Online', 'En ligne')
                        : l.t('Offline', 'Hors ligne'),
                    tone: isOnline ? BadgeTone.success : BadgeTone.danger,
                  );
                },
              ),
            ),
          ),
        ...?actions,
        if (actions != null) SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Theme.of(context).dividerColor),
      ),
    );
  }

  Widget _buildFullHeader(BuildContext context) {
    final l = DriverCopy.of(context);
    final actionButtons = <Widget>[
      ValueListenableBuilder(
        valueListenable: DriverProfileService.instance.profile,
        builder: (context, profile, _) {
          final isOnline =
              profile.onlineStatus != DriverOnlineStatus.offline;
          return StatusBadge(
            label: isOnline
                ? l.t('Online', 'En ligne')
                : l.t('Offline', 'Hors ligne'),
            tone: isOnline ? BadgeTone.success : BadgeTone.danger,
          );
        },
      ),
      // Help Center dropped from here - it's redundant with the entry points already on
      // Settings and Profile (settings_screen.dart, driver_profile_screen.dart), and with 5
      // widgets (badge + help + SOS + the dashboard's own 2 actions: scheduled rides,
      // notifications) this row's combined minimum width (~250-290px with French labels)
      // structurally exceeded the old 220px constraint, pushing the LAST item - the
      // notifications bell the driver actually needs to see - onto a second Wrap run that the
      // fixed 60px toolbarHeight then clipped. Removing the least-essential, already-duplicated
      // item is more reliable than trying to out-shrink French text in a tight budget.
      _SosButton(
        // SOS must go straight to the real emergency flow - it previously opened the Help
        // Center instead, leaving a driver in a genuine emergency one extra, unrelated tap
        // away from actual help.
        onPressed: () => Navigator.pushNamed(context, RouteNames.emergency),
      ),
      ...?actions,
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      titleSpacing: 0,
      backgroundColor: AppColors.surfaceFor(context),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pushNamed(context, RouteNames.profile),
              icon: Icon(
                Icons.account_circle_rounded,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            Expanded(
              child: Center(
                child: const AppLogo(compact: true),
              ),
            ),
            ConstrainedBox(
              // Sized for the worst case (French "Hors ligne" badge + SOS + the dashboard's own
              // 2 compact action icons): a Row with an Expanded logo in the middle degrades by
              // shrinking the logo, not by clipping this box, so erring generous here is the
              // safe direction - the alternative (too narrow) is what hid the notifications
              // bell in the first place.
              constraints: const BoxConstraints(maxWidth: 230),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 0,
                children: actionButtons,
              ),
            ),
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
