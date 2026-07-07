import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Checks for a stored token and routes to Home or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    // Let the splash frame render before hitting the network.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    bool restored;
    try {
      restored = await auth.tryRestoreSession();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => restored ? const HomeShell() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.fingerprint_rounded,
                  size: 52, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'Attendance',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Employee attendance made simple',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            if (_busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Go to login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
