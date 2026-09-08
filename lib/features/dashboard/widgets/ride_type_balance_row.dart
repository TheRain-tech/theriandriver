import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/commission_wallet.dart';
import '../../../data/models/driver_profile.dart';
import '../../../router/route_names.dart';
import '../../../services/commission_wallet_service.dart';

// Placeholder until the backend exposes a real per-driver ride type field.
const _rideType = 'Classic';

Color _rideTypeColor(String rideType) => switch (rideType) {
  'VIP' => const Color(0xFF6A1B9A),
  'Delivery' => const Color(0xFFE65100),
  _ => const Color(0xFF2E7D32),
};

/// Single "Ride Type" / "Balance" card shown under Today's Earnings on the
/// driver dashboard. Balance reads live from the real commission wallet
/// (server-updated after each trip) - no client-side deduction logic here.
class RideTypeBalanceRow extends StatefulWidget {
  const RideTypeBalanceRow({super.key, required this.profile});

  final DriverProfile profile;

  @override
  State<RideTypeBalanceRow> createState() => _RideTypeBalanceRowState();
}

class _RideTypeBalanceRowState extends State<RideTypeBalanceRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool? _wasLow;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _warnIfNewlyLow(CommissionWallet wallet) {
    final isLow = wallet.isLow || !wallet.canReceiveRides;
    if (isLow && _wasLow == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Low balance! Please recharge to continue receiving rides',
            ),
          ),
        );
      });
    }
    _wasLow = isLow;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const Expanded(child: _RideTypeSection()),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            Expanded(
              child: StreamBuilder<CommissionWallet>(
                stream: CommissionWalletService.instance.watchWalletForDriver(
                  widget.profile,
                ),
                builder: (context, snapshot) {
                  final wallet = snapshot.data;
                  final isLow =
                      wallet == null ||
                      wallet.isLow ||
                      !wallet.canReceiveRides;
                  if (wallet != null) _warnIfNewlyLow(wallet);
                  return _BalanceSection(
                    balance: wallet?.balance ?? 0,
                    isLow: isLow,
                    pulse: _pulseCtrl,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone "Ride Type" card - also used on its own by the wallet screen.
class RideTypeCard extends StatelessWidget {
  const RideTypeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const _RideTypeContent(),
    );
  }
}

class _RideTypeSection extends StatelessWidget {
  const _RideTypeSection();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12),
    child: _RideTypeContent(),
  );
}

class _RideTypeContent extends StatelessWidget {
  const _RideTypeContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Type',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _rideTypeColor(_rideType),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            _rideType,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.balance,
    required this.isLow,
    required this.pulse,
  });

  final double balance;
  final bool isLow;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  CurrencyFormatter.format(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLow ? const Color(0xFFD32F2F) : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: pulse,
                builder: (context, child) {
                  final scale = isLow ? 1.0 + (pulse.value * 0.06) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: _RechargeButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.topUp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RechargeButton extends StatelessWidget {
  const _RechargeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF6F00),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Text(
                'Recharge',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
