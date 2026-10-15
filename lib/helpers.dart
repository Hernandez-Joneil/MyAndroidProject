import 'package:flutter/material.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String two(int n) => n.toString().padLeft(2, '0');

/// Gym time (Philippines, UTC+8), whatever timezone the phone is set to.
DateTime manilaNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime manilaToday() {
  final n = manilaNow();
  return DateTime(n.year, n.month, n.day);
}

String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String prettyDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String prettyDateStr(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : prettyDate(d);
}

String prettyTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final d = parsed.toUtc().add(const Duration(hours: 8));
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class StatusChip extends StatelessWidget {
  final Map<String, dynamic> member;
  const StatusChip(this.member, {super.key});

  @override
  Widget build(BuildContext context) {
    final status = member['membership_status'] as String;
    final days = member['days_left'] as int?;
    final String label;
    final Color color;

    if (status == 'active') {
      color = Colors.green.shade700;
      label = days == 0
          ? 'Ends today'
          : days == 1
          ? '1 day left'
          : '$days days left';
    } else if (status == 'expired') {
      color = Colors.red.shade700;
      final ago = -(days ?? 0);
      label = ago == 1 ? 'Expired 1 day ago' : 'Expired $ago days ago';
    } else {
      color = Colors.grey.shade700;
      label = 'No membership';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}