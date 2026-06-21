import '../models/app_enums.dart';
import '../models/driver_transaction.dart';
import '../models/driver_wallet.dart';

final mockDriverWallet = DriverWallet(
  id: 'wallet-001',
  driverId: 'driver-001',
  balance: 42800,
  availableToWithdraw: 38500,
  minimumWithdrawal: 2000,
  payoutMethod: 'Mobile Money',
  payoutAccount: '+237 6XX XXX 211',
  updatedAt: DateTime(2026, 6, 6, 8, 30),
);

final mockDriverTransactions = <DriverTransaction>[
  DriverTransaction(
    id: 'txn-001',
    driverId: 'driver-001',
    title: 'Ride Payment',
    type: 'earning',
    amount: 2500,
    createdAt: DateTime(2026, 6, 6, 8, 30),
    status: WithdrawalStatus.completed,
  ),
  DriverTransaction(
    id: 'txn-002',
    driverId: 'driver-001',
    title: 'Bonus',
    type: 'bonus',
    amount: 500,
    createdAt: DateTime(2026, 6, 6, 7, 30),
    status: WithdrawalStatus.completed,
  ),
  DriverTransaction(
    id: 'txn-003',
    driverId: 'driver-001',
    title: 'Withdrawal',
    type: 'withdrawal',
    amount: -10000,
    createdAt: DateTime(2026, 6, 5, 22, 20),
    status: WithdrawalStatus.completed,
  ),
  DriverTransaction(
    id: 'txn-004',
    driverId: 'driver-001',
    title: 'Subscription',
    type: 'subscription',
    amount: -2000,
    createdAt: DateTime(2026, 5, 20, 10),
    status: WithdrawalStatus.completed,
  ),
];
