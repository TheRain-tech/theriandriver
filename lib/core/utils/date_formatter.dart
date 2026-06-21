import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static String short(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String time(DateTime date) => DateFormat('hh:mm a').format(date);
  static String full(DateTime date) =>
      DateFormat('EEE, dd MMM yyyy • hh:mm a').format(date);
}
