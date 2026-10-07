import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../widgets.dart';
import '../config.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final tabs = [const BookTab(), const MyAppointmentsTab(), const MyPlansTab()];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(clinicName, style: const TextStyle(fontWeight: FontWeight.w800, color: kTeal)),
        actions: [
          Center(child: Text('Hi, ${auth.user!['name']}')),
          IconButton(tooltip: 'Log out', onPressed: auth.logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: tabs[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_available), label: 'Book'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'My visits'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'My exercises'),
        ],
      ),
    );
  }
}

class BookTab extends StatefulWidget {
  const BookTab({super.key});
  @override
  State<BookTab> createState() => _BookTabState();
}

class _BookTabState extends State<BookTab> {
  List _services = [];
  List _slots = [];
  String? _serviceId, _slot;
  DateTime? _date;
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthState>().api.get('/api/services').then((s) => setState(() => _services = s));
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date!);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _date ?? DateTime.now(),
    );
    if (d == null) return;
    setState(() {
      _date = d;
      _slot = null;
      _slots = [];
    });
    try {
      final s = await context.read<AuthState>().api.get('/api/slots?date=$_dateStr');
      if (mounted) setState(() => _slots = s);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _book() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().api.post('/api/appointments', {
        'serviceId': _serviceId,
        'date': _dateStr,
        'time': _slot,
        'notes': _notes.text,
      });
      if (!mounted) return;
      toast(context, 'Booked. The clinic will confirm shortly.');
      setState(() {
        _slot = null;
        _slots = [];
        _date = null;
        _notes.clear();
      });
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _serviceId != null && _date != null && _slot != null;
    return SingleChildScrollView(
      child: Page(
        maxWidth: 560,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Book a visit', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _serviceId,
            decoration: const InputDecoration(labelText: 'Treatment'),
            items: [
              for (final s in _services)
                DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}  (₹${s['price']})')),
            ],
            onChanged: (v) => setState(() => _serviceId = v),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_date == null ? 'Choose a date' : DateFormat('EEE, d MMM yyyy').format(_date!)),
          ),
          const SizedBox(height: 16),
          if (_date != null && _slots.isEmpty) const Text('No free slots on this day. Try another date.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _slots)
              ChoiceChip(label: Text('$s'), selected: _slot == s, onSelected: (_) => setState(() => _slot = s)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'What brings you in? (optional)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ready && !_busy ? _book : null,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_busy ? 'Booking...' : 'Book appointment')),
          ),
        ]),
      ),
    );
  }
}

class MyAppointmentsTab extends StatelessWidget {
  const MyAppointmentsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Loader<List>(
      load: () async => (await api.get('/api/appointments')) as List,
      builder: (_, list, reload) => RefreshIndicator(
        onRefresh: () async => reload(),
        child: list.isEmpty
            ? const Center(child: Text('No visits yet. Use the Book tab to schedule one.'))
            : ListView(children: [
                Page(
                  child: Column(children: [
                    for (final a in list)
                      Card(
                        child: ListTile(
                          title: Text(a['serviceName'], style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${a['date']} at ${a['time']}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            StatusChip(a['status']),
                            if (a['status'] == 'pending' || a['status'] == 'confirmed')
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await api.patch('/api/appointments/${a['id']}/status', {'status': 'cancelled'});
                                    reload();
                                  } catch (e) {
                                    toast(context, '$e', error: true);
                                  }
                                },
                                child: const Text('Cancel'),
                              ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ]),
      ),
    );
  }
}

class MyPlansTab extends StatelessWidget {
  const MyPlansTab({super.key});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Loader<List>(
      load: () async => (await api.get('/api/plans')) as List,
      builder: (_, list, __) => list.isEmpty
          ? const Center(child: Text('Your therapist has not added an exercise plan yet.'))
          : ListView(children: [
              Page(
                child: Column(children: [
                  for (final p in list)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['title'], style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          if ('${p['instructions']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p['instructions'])),
                          const Divider(height: 24),
                          for (final e in (p['exercises'] as List))
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle_outline, color: kTeal),
                              title: Text(e['name']),
                              subtitle: Text('${e['sets']} sets x ${e['reps']} reps'),
                            ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
    );
  }
}
