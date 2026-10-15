import 'admin_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'login_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _controller.text.trim();
    if (username.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.checkIn(username);
      _showResult(r);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _backToLogin();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(Map<String, dynamic> r) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _result = r);
    final seconds = r['result'] == 'valid' ? 4 : 7;
    _timer = Timer(Duration(seconds: seconds), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _result = null;
      _error = null;
      _controller.clear();
    });
  }

  Future<void> _backToLogin() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _menu(String action) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || !mounted) return;

    bool ok;
    try {
      ok = await Api.verifyAdminPassword(password);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
      return;
    }
    if (!mounted) return;
    if (!ok) {
      _snack('Wrong admin password.');
      return;
    }

    if (action == 'logout') {
      await _backToLogin();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _result == null
          ? AppBar(
              title: const Text('Bakal Gym'),
              actions: [
                PopupMenuButton<String>(
                  onSelected: _menu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'dashboard', child: Text('Admin dashboard')),
                    PopupMenuItem(value: 'logout', child: Text('Log out')),
                  ],
                ),
              ],
            )
          : null,
      body: _result == null ? _form(context) : _resultView(_result!),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.fitness_center, size: 72, color: scheme.primary),
                const SizedBox(height: 12),
                Text('Welcome to Bakal Gym',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Enter your username to check in',
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check In', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultView(Map<String, dynamic> r) {
    final result = r['result'] as String;
    final Color color;
    final IconData icon;
    final String title;
    switch (result) {
      case 'valid':
        color = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        title = 'Thank you!';
        break;
      case 'expired':
        color = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        title = 'Membership Expired';
        break;
      default:
        color = Colors.red.shade700;
        icon = Icons.block;
        title = 'Not Allowed';
    }

    return GestureDetector(
      onTap: _dismiss,
      child: Container(
        color: color,
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(32),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 120, color: Colors.white),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold)),
              if (result != 'valid') ...[
                const SizedBox(height: 12),
                Text('${r['full_name']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Text('${r['message']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 40),
              const Text('Tap anywhere to continue',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin password'),
      content: TextField(
        controller: _c,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}