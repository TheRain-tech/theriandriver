import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_transaction.dart';
import '../../../data/models/driver_wallet.dart';
import '../../../data/repositories/driver_wallet_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/commission_wallet_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/transaction_tile.dart';

import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _repository = DriverWalletRepository();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(
      title: 'Wallet',
      showLogo: false,
      showOnline: true,
    ),
    body: StreamBuilder<DriverWallet>(
      stream: _repository.watchWallet(),
      builder: (context, walletSnapshot) {
        if (walletSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState(label: 'Retrieving wallet balance...');
        }
        if (walletSnapshot.hasError) {
          return ErrorState(
            message: 'We could not load your wallet details. Please try again.',
            onRetry: () => setState(() {}),
          );
        }
        final wallet = walletSnapshot.data;

        if (wallet == null) {
          return const EmptyState(
            title: 'No Wallet Found',
            message:
                'We could not find a wallet profile registered for your account.',
            icon: Icons.account_balance_wallet_outlined,
          );
        }

        return StreamBuilder<List<DriverTransaction>>(
          stream: _repository.watchTransactions(),
          builder: (context, transactionsSnapshot) {
            final transactions = transactionsSnapshot.data ?? const [];

            return SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wallet Balance'),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.format(wallet.balance),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const Divider(height: 30),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Available to Withdraw'),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    wallet.availableToWithdraw,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const CircleAvatar(
                                  radius: 5,
                                  backgroundColor: AppColors.success,
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Expanded(child: Text('Pending Balance')),
                                Text(
                                  CurrencyFormatter.format(
                                    wallet.pendingBalance,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const CircleAvatar(
                                  radius: 5,
                                  backgroundColor: AppColors.warning,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder(
                        valueListenable: DriverProfileService.instance.profile,
                        builder: (context, profile, _) {
                          return StreamBuilder(
                            stream: CommissionWalletService.instance
                                .watchWalletForDriver(profile),
                            builder: (context, commissionSnapshot) {
                              final commissionWallet = commissionSnapshot.data;
                              return AppCard(
                                color: commissionWallet?.canReceiveRides == true
                                    ? AppColors.successSoft
                                    : AppColors.dangerSoft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Commission Balance'),
                                    const SizedBox(height: 8),
                                    Text(
                                      CurrencyFormatter.format(
                                        commissionWallet?.balance ?? 0,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      commissionWallet?.canReceiveRides == true
                                          ? 'Ready to receive rides.'
                                          : 'Top up your commission balance to receive rides.',
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Withdraw',
                        icon: Icons.arrow_downward_rounded,
                        onPressed: () =>
                            Navigator.pushNamed(context, RouteNames.withdraw),
                      ),
                      const SizedBox(height: 10),
                      AppOutlineButton(
                        label: 'Transaction History',
                        icon: Icons.history_rounded,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          RouteNames.withdrawalHistory,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppCard(
                        child: Row(
                          children: [
                            const IconWell(icon: Icons.phone_android_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LabeledValue(
                                label: 'Payout Method',
                                value:
                                    '${wallet.payoutMethod}\n${wallet.payoutAccount}',
                              ),
                            ),
                            const Text(
                              'Default',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(
                        title: 'Recent Transactions',
                        actionLabel: 'See all',
                      ),
                      if (transactions.isEmpty)
                        const AppCard(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No recent transactions found.',
                              style: TextStyle(color: AppColors.slate),
                            ),
                          ),
                        )
                      else
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              for (var i = 0; i < transactions.length; i++) ...[
                                TransactionTile(transaction: transactions[i]),
                                if (i < transactions.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 3),
  );
}
