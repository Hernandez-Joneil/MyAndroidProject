import 'package:flutter/material.dart';

import 'api.dart';
import 'helpers.dart';

class MemberFormScreen extends StatefulWidget {
  final Map<String, dynamic>? member;
  const MemberFormScreen({super.key, this.member});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  static const _types = ['weekly', 'monthly', 'quarterly', 'yearly'];

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _validId = TextEditingController();
  Map<String, dynamic>? _member;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    final m = _member;
    if (m != null) {
      _name.text = m['full_name'] as String;
      _username.text = m['username'] as String;
      _email.text = m['email'] as String;
      _validId.text = m['valid_id'] as String;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _validId.dispose();
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

  Future<Map<String, dynamic>?> _fetch(String username) async {
    final list = await Api.getMembers(search: username);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      if ((m['username'] as String).toLowerCase() == username.toLowerCase()) {
        return m;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    final m = _member;
    if (m == null) return;
    final fresh = await _fetch(m['username'] as String);
    if (fresh != null && mounted) setState(() => _member = fresh);
  }

  Future<void> _save() async {
    if (_busy) return;
    final body = <String, String>{
      'full_name': _name.text.trim(),
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'valid_id': _validId.text.trim(),
    };
    if (body.values.any((v) => v.isEmpty)) {
      _say('Please fill in every field.');
      return;
    }
    setState(() => _busy = true);
    try {
      final current = _member;
      if (current == null) {
        await Api.createMember(body);
        final fresh = await _fetch(body['username']!);
        if (mounted) setState(() => _member = fresh);
        _say('Member added. Now choose a membership below.');
      } else {
        await Api.updateMember(current['id'] as int, body);
        final fresh = await _fetch(body['username']!);
        if (fresh != null && mounted) setState(() => _member = fresh);
        _say('Changes saved.');
      }
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setMembership(String type) async {
    final m = _member!;
    final ok = await _confirm(
      '${cap(type)} membership',
      'Give ${m['full_name']} a $type membership? If the current one is '
          'still active, the new one starts right after it ends.',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.setMembership(m['id'] as int, type);
      await _refresh();
      _say('${cap(type)} membership set.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeDeadline() async {
    final m = _member!;
    final id = m['membership_id'] as int?;
    if (id == null) {
      _say('Set a membership first.');
      return;
    }
    final current =
        DateTime.tryParse(m['expiration_date'] as String? ?? '') ??
            manilaToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'New expiration date',
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await Api.editMembership(id, ymd(picked));
      await _refresh();
      _say('Expiration date updated.');
    } on ApiException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final m = _member!;
    final ok = await _confirm(
      'Delete member',
      'Delete ${m['full_name']} and all their memberships and attendance '
          'records? This cannot be undone.',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.deleteMember(m['id'] as int);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _say(e.message);
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label,
      {String? helper,
        TextInputType? keyboard,
        TextCapitalization caps = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        textCapitalization: caps,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  List<Widget> _membershipSection(Map<String, dynamic> m) {
    final hasMembership = m['membership_id'] != null;
    return [
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 8),
      Text('Membership',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusChip(m),
              const SizedBox(height: 10),
              if (hasMembership) ...[
                Text(
                    '${cap(m['membership_type'] as String)}  •  started ${prettyDateStr(m['start_date'] as String?)}'),
                const SizedBox(height: 4),
                Text('Ends ${prettyDateStr(m['expiration_date'] as String?)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ] else
                const Text('No membership yet.'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Set membership (deadline is computed automatically):'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in _types)
            FilledButton.tonal(
              onPressed: _busy ? null : () => _setMembership(t),
              child: Text(cap(t)),
            ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : _changeDeadline,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Change expiration date'),
      ),
      const SizedBox(height: 24),
      TextButton.icon(
        onPressed: _busy ? null : _delete,
        icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
        label: Text('Delete member',
            style: TextStyle(color: Colors.red.shade700)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    return Scaffold(
      appBar: AppBar(title: Text(m == null ? 'Add member' : 'Edit member')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_name, 'Full name', caps: TextCapitalization.words),
          _field(_username, 'Username',
              helper: '3-30 characters: letters, numbers, _ or .'),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_validId, 'Valid ID (type and number)'),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _busy
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(m == null ? 'Add member' : 'Save changes'),
            ),
          ),
          if (m != null) ..._membershipSection(m),
        ],
      ),
    );
  }
}