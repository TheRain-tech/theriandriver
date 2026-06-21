import '../data/repositories/driver_wallet_repository.dart';
import '../data/models/driver_transaction.dart';
import '../data/models/driver_wallet.dart';

class WalletService {
  WalletService({DriverWalletRepository? repository})
    : _repository = repository ?? DriverWalletRepository();

  final DriverWalletRepository _repository;

  Future<DriverWallet> getWallet() => _repository.getWallet();
  Future<List<DriverTransaction>> getTransactions() =>
      _repository.getTransactions();
}
