import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0', 'en_US');
final _money2 = NumberFormat('#,##0.##', 'en_US');

/// "Le 90" / "Le 1,250" / "- Le 45". Leones (SLE), whole amounts unless there are cents.
String le(num amount, {bool signed = false}) {
  final abs = amount.abs();
  final text = 'Le ${abs == abs.roundToDouble() ? _money.format(abs) : _money2.format(abs)}';
  if (!signed || amount == 0) return amount < 0 ? '- $text' : text;
  return amount < 0 ? '- $text' : '+ $text';
}

/// "Today, 9:12 AM" / "Yesterday, 6:40 PM" / "23 May, 4:15 PM".
String friendlyDateTime(DateTime t) {
  final local = t.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = DateFormat('h:mm a').format(local);
  if (day == today) return 'Today, $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
  return '${DateFormat('d MMM').format(local)}, $time';
}

/// "Tue, 27 May 2025 • 4:20 PM" as on the Activity cards.
String tripDate(DateTime t) => DateFormat("EEE, d MMM y '•' h:mm a").format(t.toLocal());

String clock(DateTime t) => DateFormat('h:mm a').format(t.toLocal());

/// "+232 76 123 456"
String prettyPhone(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('232')) {
    return '+232 ${d.substring(3, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
  }
  return e164;
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String firstName(String full) => full.trim().split(RegExp(r'\s+')).first;

String initials(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}
