import 'package:intl/intl.dart';

class Fmt {
  static final _money = NumberFormat.simpleCurrency();
  static String money(num v) => _money.format(v);
}
