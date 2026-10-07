import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state.dart';
import '../widgets.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    const tabs = <Widget>[OverviewTab(), AppointmentsAdminTab(), PatientsTab(), ServicesTab(), PlansAdminTab()];
    const items = [
      (Icons.dashboard, 'Overview'),
      (Icons.event, 'Appointments'),
      (Icons.people, 'Patients'),
      (Icons.medical_services, 'Services'),
      (Icons.fitness_center, 'Exercise plans'),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('$clinicName  |  Admin', style: const TextStyle(fontWeight: FontWeight.w800, color: kTeal)),
        actions: [IconButton(tooltip: 'Log out', onPressed: auth.logout, icon: const Icon(Icons.logout))],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          labelType: NavigationRailLabelType.all,
          destinations: [for (final it in items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2))],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: tabs[_i]),
      ]),
    );
  }
}

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Loader<Map>(
      load: () async => (await api.get('/api/stats')) as Map,
      builder: (_, s, __) {
        Widget tile(String label, Object v) => SizedBox(
              width: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$v', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: kTeal)),
                    Text(label),
                  ]),
                ),
              ),
            );
        return Page(
          maxWidth: 1000,
          child: Wrap(spacing: 16, runSpacing: 16, children: [
            tile('Patients', s['patients']),
            tile('Visits today', s['today']),
            tile('Awaiting confirmation', s['pending']),
            tile('Completed visits', s['completed']),
            tile('Revenue from completed visits', '₹${s['revenue']}'),
          ]),
        );
      },
    );
  }
}

class AppointmentsAdminTab extends StatelessWidget {
  const AppointmentsAdminTab({super.key});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    Future<void> setStatus(String id, String st, VoidCallback reload) async {
      try {
        await api.patch('/api/appointments/$id/status', {'status': st});
        reload();
      } catch (e) {
        toast(context, '$e', error: true);
      }
    }

    return Loader<List>(
      load: () async => (await api.get('/api/appointments')) as List,
      builder: (_, list, reload) => list.isEmpty
          ? const Center(child: Text('No appointments yet.'))
          : ListView(children: [
              Page(
                maxWidth: 1000,
                child: Column(children: [
                  for (final a in list)
                    Card(
                      child: ListTile(
                        title: Text('${a['patientName']}  -  ${a['serviceName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${a['date']} at ${a['time']}${'${a['notes']}'.isEmpty ? '' : '\nNote: ${a['notes']}'}'),
                        isThreeLine: '${a['notes']}'.isNotEmpty,
                        trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          StatusChip(a['status']),
                          if (a['status'] == 'pending')
                            FilledButton(onPressed: () => setStatus(a['id'], 'confirmed', reload), child: const Text('Confirm')),
                          if (a['status'] == 'confirmed')
                            FilledButton(onPressed: () => setStatus(a['id'], 'completed', reload), child: const Text('Mark done')),
                          if (a['status'] == 'pending' || a['status'] == 'confirmed')
                            TextButton(onPressed: () => setStatus(a['id'], 'cancelled', reload), child: const Text('Cancel')),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
    );
  }
}

class PatientsTab extends StatelessWidget {
  const PatientsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Loader<List>(
      load: () async => (await api.get('/api/patients')) as List,
      builder: (_, list, __) => list.isEmpty
          ? const Center(child: Text('No patients have registered yet.'))
          : ListView(children: [
              Page(
                child: Column(children: [
                  for (final p in list)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${p['email']}   ${p['phone'] ?? ''}'),
                      ),
                    ),
                ]),
              ),
            ]),
    );
  }
}

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  Key _k = UniqueKey();

  Future<void> _add() async {
    final name = TextEditingController(), desc = TextEditingController(), dur = TextEditingController(text: '45'), price = TextEditingController();
    final api = context.read<AuthState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a service'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            TextField(controller: dur, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)')),
            const SizedBox(height: 10),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save service')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/api/services', {'name': name.text, 'description': desc.text, 'durationMin': dur.text, 'price': price.text});
      setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add service')),
      body: Loader<List>(
        key: _k,
        load: () async => (await api.get('/api/services')) as List,
        builder: (_, list, reload) => ListView(children: [
          Page(
            child: Column(children: [
              for (final s in list)
                Card(
                  child: ListTile(
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${s['description']}\n${s['durationMin']} min  |  ₹${s['price']}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Delete service',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await api.delete('/api/services/${s['id']}');
                        reload();
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PlansAdminTab extends StatefulWidget {
  const PlansAdminTab({super.key});
  @override
  State<PlansAdminTab> createState() => _PlansAdminTabState();
}

class _PlansAdminTabState extends State<PlansAdminTab> {
  Key _k = UniqueKey();

  Future<void> _add() async {
    final api = context.read<AuthState>().api;
    final patients = (await api.get('/api/patients')) as List;
    if (!mounted) return;
    if (patients.isEmpty) return toast(context, 'Register a patient first.', error: true);
    String patientId = patients.first['id'];
    final title = TextEditingController(), notes = TextEditingController(), ex = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('New exercise plan'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: patientId,
                  decoration: const InputDecoration(labelText: 'Patient'),
                  items: [for (final p in patients) DropdownMenuItem(value: p['id'] as String, child: Text(p['name']))],
                  onChanged: (v) => setD(() => patientId = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Plan title')),
                const SizedBox(height: 10),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions')),
                const SizedBox(height: 10),
                TextField(
                  controller: ex,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Exercises, one per line',
                    hintText: 'Name | sets | reps\nBridge | 3 | 12',
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Assign plan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final exercises = ex.text.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      final p = l.split('|').map((e) => e.trim()).toList();
      return {'name': p[0], 'sets': p.length > 1 ? p[1] : '-', 'reps': p.length > 2 ? p[2] : '-'};
    }).toList();
    try {
      await api.post('/api/plans', {'patientId': patientId, 'title': title.text, 'instructions': notes.text, 'exercises': exercises});
      setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('New plan')),
      body: Loader<List>(
        key: _k,
        load: () async => (await api.get('/api/plans')) as List,
        builder: (_, list, __) => list.isEmpty
            ? const Center(child: Text('No plans yet. Assign one to a patient.'))
            : ListView(children: [
                Page(
                  child: Column(children: [
                    for (final p in list)
                      Card(
                        child: ListTile(
                          title: Text('${p['title']}  for  ${p['patientName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text((p['exercises'] as List).map((e) => '${e['name']} (${e['sets']}x${e['reps']})').join(', ')),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ]),
      ),
    );
  }
}
