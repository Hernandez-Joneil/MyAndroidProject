import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'helpers.dart';
import 'member_form_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  Future<void> _sendReminders() async {
    String text;
    try {
      final n = await Api.sendReminders();
      text = n == 0
          ? 'No reminders are due today.'
          : '$n reminder email(s) sent. Check Mailpit.';
    } on ApiException catch (e) {
      text = e.message;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Members' : 'Attendance'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _sendReminders(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remind', child: Text('Send reminders now')),
            ],
          ),
        ],
      ),
      body: _tab == 0 ? const _MembersTab() : const _AttendanceTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(
              icon: Icon(Icons.fact_check), label: 'Attendance'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Members

class _MembersTab extends StatefulWidget {
  const _MembersTab();

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  static const _filters = [
    ('', 'All'),
    ('active', 'Active'),
    ('expired', 'Expired'),
    ('none', 'No membership'),
  ];

  final _search = TextEditingController();
  Timer? _debounce;
  String _status = '';
  List<dynamic> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
      await Api.getMembers(search: _search.text.trim(), status: _status);
      if (mounted) setState(() => _members = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic>? member) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberFormScreen(member: member)),
    );
    if (mounted) _load();
  }

  Widget _body() {
    if (_loading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(child: Text('No members found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = _members[i] as Map<String, dynamic>;
          final exp = m['expiration_date'] as String?;
          return ListTile(
            title: Text(m['full_name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(exp == null
                ? '@${m['username']}'
                : '@${m['username']}  •  ends ${prettyDateStr(exp)}'),
            trailing: StatusChip(m),
            onTap: () => _open(m),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(null),
        icon: const Icon(Icons.person_add),
        label: const Text('Add member'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name or username',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _status == f.$1,
                      onSelected: (_) {
                        setState(() => _status = f.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Attendance

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _day = manilaToday();
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.getAttendance(day: ymd(_day));
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int days) {
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));
    _load();
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _day = picked);
      _load();
    }
  }

  Widget _list() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No check-ins on this day.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _rows[i] as Map<String, dynamic>;
          final result = r['result'] as String;
          final Color color;
          final IconData icon;
          if (result == 'valid') {
            color = Colors.green.shade700;
            icon = Icons.check_circle;
          } else if (result == 'expired') {
            color = Colors.orange.shade800;
            icon = Icons.warning_amber_rounded;
          } else {
            color = Colors.red.shade700;
            icon = Icons.block;
          }
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(r['full_name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('@${r['username']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(prettyTime(r['checked_in_at'] as String)),
                Text(result.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: TextButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(prettyDate(_day)),
                ),
              ),
              IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${_rows.length} check-in(s)',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const Divider(height: 1),
        Expanded(child: _list()),
      ],
    );
  }
}