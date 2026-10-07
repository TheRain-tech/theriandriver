import 'package:flutter/material.dart';
import '../../../core/localization/driver_copy.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_transaction.dart';
import '../../../data/models/driver_wallet.dart';
import '../../../data/models/driver_wallet_requirement.dart';
import '../../../data/repositories/driver_wallet_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/commission_wallet_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/widgets/ride_type_balance_row.dart';
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
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
    appBar: DriverAppBar(
      title: l.t('Wallet', 'Portefeuille'),
      showLogo: false,
      showOnline: true,
    ),
    body: StreamBuilder<DriverWallet>(
      stream: _repository.watchWallet(),
      builder: (context, walletSnapshot) {
        if (walletSnapshot.connectionState == ConnectionState.waiting) {
          return LoadingState(label: l.t('Retrieving wallet balance...', 'Récupération du solde du portefeuille...'));
        }
        if (walletSnapshot.hasError) {
          return ErrorState(
            message: l.t(
              'We could not load your wallet details. Please try again.',
              'Impossible de charger les détails de votre portefeuille. Veuillez réessayer.',
            ),
            onRetry: () => setState(() {}),
          );
        }
        final wallet = walletSnapshot.data;

        if (wallet == null) {
          return EmptyState(
            title: l.t('No Wallet Found', 'Aucun portefeuille trouvé'),
            message: l.t(
              'We could not find a wallet profile registered for your account.',
              'Nous n\'avons trouvé aucun profil de portefeuille enregistré pour votre compte.',
            ),
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
                            Text(l.t('Wallet Balance', 'Solde du portefeuille')),
                            SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.format(wallet.balance),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            Divider(height: 30),
                            Row(
                              children: [
                                Expanded(child: Text(l.t('Available to Withdraw', 'Disponible pour retrait'))),
                                Text(
                                  CurrencyFormatter.format(
                                    wallet.availableToWithdraw,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textPrimaryFor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 5,
                                  backgroundColor: AppColors.success,
                                ),
                              ],
                            ),
                            Divider(height: 20),
                            Row(
                              children: [
                                Expanded(child: Text(l.t('Pending Balance', 'Solde en attente'))),
                                Text(
                                  CurrencyFormatter.format(
                                    wallet.pendingBalance,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondaryFor(context),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 5,
                                  backgroundColor: AppColors.warning,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const RideTypeCard(),
                      const SizedBox(height: 18),
                      ValueListenableBuilder(
                        valueListenable: DriverProfileService.instance.profile,
                        builder: (context, profile, _) {
                          final copy = DriverCopy.of(context);
                          final category = walletCategoryOf(profile);
                          // Only a driver who pays commission from their own wallet is asked to top up.
                          if (category == DriverWalletCategory.therainManaged) {
                            return AppCard(
                              color: AppColors.successSoftFor(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    copy.t(
                                      'TheRain-managed account',
                                      'Compte géré par TheRain',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    copy.t(
                                      'No wallet balance is required to go online or accept rides.',
                                      "Aucun solde de portefeuille n'est requis pour se mettre en ligne ou accepter des courses.",
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (category == DriverWalletCategory.fleet) {
                            return AppCard(
                              color: AppColors.successSoftFor(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    copy.t(
                                      'Fleet wallet',
                                      'Portefeuille de la flotte',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    copy.t(
                                      "Your Fleet Owner's wallet pays the TheRain commission on your trips. If it falls below the required minimum you cannot go online or accept rides until they recharge it.",
                                      "Le portefeuille de votre propriétaire de flotte paie la commission TheRain sur vos courses. S'il passe sous le minimum requis, vous ne pouvez plus vous mettre en ligne ni accepter de courses tant qu'il n'est pas rechargé.",
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return StreamBuilder(
                            stream: CommissionWalletService.instance
                                .watchWalletForDriver(profile),
                            builder: (context, commissionSnapshot) {
                              final commissionWallet = commissionSnapshot.data;
                              return AppCard(
                                color: commissionWallet?.canReceiveRides == true
                                    ? AppColors.successSoftFor(context)
                                    : AppColors.dangerSoftFor(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(copy.t('Commission Balance', 'Solde de commission')),
                                    SizedBox(height: 8),
                                    Text(
                                      CurrencyFormatter.format(
                                        commissionWallet?.balance ?? 0,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      commissionWallet?.canReceiveRides == true
                                          ? copy.t(
                                              'Ready to receive rides.',
                                              'Prêt à recevoir des courses.',
                                            )
                                          : copy.t(
                                              'Add at least ${CurrencyFormatter.format(((commissionWallet?.minimumRequiredBalance ?? 0) - (commissionWallet?.balance ?? 0)).clamp(0, double.infinity))} to your TheRain wallet to go online and accept rides.',
                                              'Ajoutez au moins ${CurrencyFormatter.format(((commissionWallet?.minimumRequiredBalance ?? 0) - (commissionWallet?.balance ?? 0)).clamp(0, double.infinity))} à votre portefeuille TheRain pour vous mettre en ligne et accepter des courses.',
                                            ),
                                    ),
                                    if (commissionWallet?.canReceiveRides !=
                                        true) ...[
                                      SizedBox(height: 14),
                                      AppOutlineButton(
                                        label: copy.t('Top Up', 'Recharger'),
                                        icon: Icons.add_circle_outline_rounded,
                                        onPressed: () async {
                                          final result =
                                              await Navigator.pushNamed(
                                                context,
                                                RouteNames.topUp,
                                              );
                                          if (result == true) setState(() {});
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: 18),
                      PrimaryButton(
                        label: l.t('Withdraw', 'Retirer'),
                        icon: Icons.arrow_downward_rounded,
                        onPressed: () =>
                            Navigator.pushNamed(context, RouteNames.withdraw),
                      ),
                      SizedBox(height: 10),
                      AppOutlineButton(
                        label: l.t('Transaction History', 'Historique des transactions'),
                        icon: Icons.history_rounded,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          RouteNames.withdrawalHistory,
                        ),
                      ),
                      SizedBox(height: 18),
                      AppCard(
                        child: Row(
                          children: [
                            IconWell(icon: Icons.phone_android_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: LabeledValue(
                                label: l.t('Payout Method', 'Méthode de paiement'),
                                value:
                                    '${wallet.payoutMethod}\n${wallet.payoutAccount}',
                              ),
                            ),
                            Text(
                              l.t('Default', 'Par défaut'),
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                      SectionHeader(
                        title: l.t('Recent Transactions', 'Transactions récentes'),
                        actionLabel: l.t('See all', 'Voir tout'),
                      ),
                      if (transactions.isEmpty)
                        AppCard(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              l.t('No recent transactions found.', 'Aucune transaction récente trouvée.'),
                              style: TextStyle(
                                color: AppColors.textSecondaryFor(context),
                              ),
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
                                  Divider(height: 1),
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
}
