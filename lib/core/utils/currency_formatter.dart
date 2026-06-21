import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'en_US');

  static String format(num amount, {bool withCode = true}) {
    final value = _format.format(amount);
    return withCode ? '$value XAF' : value;
  }
}
