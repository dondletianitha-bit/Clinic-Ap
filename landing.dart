import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state.dart';
import '../widgets.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(clinicName, style: const TextStyle(fontWeight: FontWeight.w800, color: kTeal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(register: false))),
            child: const Text('Log in'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(register: true))),
              child: const Text('Book a visit'),
            ),
          ),
        ],
      ),
      body: ListView(children: [
        Container(
          color: kTeal,
          padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pain-free movement starts with a plan built for you.',
                    style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 16),
                Text(clinicTagline, style: t.titleMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kAmber, foregroundColor: Colors.black),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(register: true))),
                  child: const Padding(padding: EdgeInsets.all(8), child: Text('Create an account and book')),
                ),
              ]),
            ),
          ),
        ),
        Page(
          maxWidth: 1000,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Text('Treatments', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Loader<List>(
              load: () async => (await context.read<AuthState>().api.get('/api/services')) as List,
              builder: (_, services, __) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final s in services)
                    SizedBox(
                      width: 300,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s['name'], style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(s['description'] ?? ''),
                            const SizedBox(height: 10),
                            Text('${s['durationMin']} min  |  ₹${s['price']}',
                                style: const TextStyle(color: kTeal, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text('How it works', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const _Step(1, 'Create your account', 'Takes under a minute.'),
            const _Step(2, 'Pick a treatment and a time', 'You only see slots that are free.'),
            const _Step(3, 'Get your exercise plan online', 'Your therapist adds it after your visit.'),
            const SizedBox(height: 40),
            Text('Visit us', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$clinicAddress\nPhone: $clinicPhone\nMon to Sat, 9:00 to 18:00'),
            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title, sub;
  const _Step(this.n, this.title, this.sub);
  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(backgroundColor: kTeal, foregroundColor: Colors.white, child: Text('$n')),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
      );
}

class AuthScreen extends StatefulWidget {
  final bool register;
  const AuthScreen({super.key, required this.register});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _register = widget.register;
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _pw = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    final auth = context.read<AuthState>();
    setState(() => _busy = true);
    try {
      if (_register) {
        await auth.register(_name.text, _email.text, _phone.text, _pw.text);
      } else {
        await auth.login(_email.text, _pw.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_register ? 'Create your account' : 'Log in')),
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  if (_register) ...[
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 14),
                    TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                    const SizedBox(height: 14),
                  ],
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_busy ? 'Please wait...' : (_register ? 'Create account' : 'Log in')),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register ? 'Already have an account? Log in' : 'New here? Create an account'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
