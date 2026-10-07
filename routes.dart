import 'dart:convert';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'auth.dart';
import 'store.dart';

const _uuid = Uuid();
const clinicSlots = [
  '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00'
];
const validStatuses = ['pending', 'confirmed', 'completed', 'cancelled'];

Map<String, dynamic> _pub(Map<String, dynamic> u) => {
      'id': u['id'],
      'name': u['name'],
      'email': u['email'],
      'phone': u['phone'],
      'role': u['role'],
    };

Future<Map<String, dynamic>> _body(Request req) async {
  try {
    return Map<String, dynamic>.from(jsonDecode(await req.readAsString()));
  } catch (_) {
    return {};
  }
}

void seed(Store db) {
  if (db.col('users').isEmpty) {
    db.col('users').add({
      'id': _uuid.v4(),
      'name': 'Clinic Admin',
      'email': 'admin@clinic.com',
      'phone': '',
      'role': 'admin',
      'password': DBCrypt().hashpw('Admin@123', DBCrypt().gensalt()),
      'createdAt': DateTime.now().toIso8601String(),
    });
    {
      for (final s in [
        ['Initial Assessment', 'Full posture and movement assessment', 45, 800],
        ['Back & Neck Pain Therapy', 'Manual therapy and guided exercise', 45, 1000],
        ['Sports Injury Rehab', 'Return-to-play programs', 60, 1200],
        ['Post-Surgery Rehabilitation', 'Recovery after orthopaedic surgery', 60, 1300],
      ]) {
        db.col('services').add({
          'id': _uuid.v4(),
          'name': s[0],
          'description': s[1],
          'durationMin': s[2],
          'price': s[3],
        });
      }
    }
    db.save();
  }
}

Router buildRouter(Store db) {
  final r = Router();

  // ---------- Auth ----------
  r.post('/api/auth/register', (Request req) async {
    final b = await _body(req);
    final name = (b['name'] ?? '').toString().trim();
    final email = (b['email'] ?? '').toString().trim().toLowerCase();
    final pw = (b['password'] ?? '').toString();
    if (name.isEmpty || !email.contains('@') || pw.length < 6) {
      return json({'error': 'Enter your name, a valid email and a password of 6+ characters'}, 400);
    }
    if (db.col('users').any((u) => u['email'] == email)) {
      return json({'error': 'This email is already registered'}, 409);
    }
    final user = <String, dynamic>{
      'id': _uuid.v4(),
      'name': name,
      'email': email,
      'phone': (b['phone'] ?? '').toString(),
      'role': 'patient',
      'password': DBCrypt().hashpw(pw, DBCrypt().gensalt()),
      'createdAt': DateTime.now().toIso8601String(),
    };
    db.col('users').add(user);
    db.save();
    return json({'token': signToken(user), 'user': _pub(user)}, 201);
  });

  r.post('/api/auth/login', (Request req) async {
    final b = await _body(req);
    final email = (b['email'] ?? '').toString().trim().toLowerCase();
    final pw = (b['password'] ?? '').toString();
    final matches = db.col('users').where((u) => u['email'] == email);
    if (matches.isEmpty || !DBCrypt().checkpw(pw, matches.first['password'])) {
      return json({'error': 'Email or password is incorrect'}, 401);
    }
    return json({'token': signToken(matches.first), 'user': _pub(matches.first)});
  });

  r.get('/api/me', (Request req) {
    final denied = guard(req);
    if (denied != null) return denied;
    final u = db.col('users').where((u) => u['id'] == userOf(req)!['id']);
    if (u.isEmpty) return json({'error': 'Account not found'}, 404);
    return json(_pub(u.first));
  });

  // ---------- Services ----------
  r.get('/api/services', (Request req) => json(db.col('services')));

  r.post('/api/services', (Request req) async {
    final denied = guard(req, 'admin');
    if (denied != null) return denied;
    final b = await _body(req);
    if ((b['name'] ?? '').toString().trim().isEmpty) {
      return json({'error': 'Service name is required'}, 400);
    }
    final s = {
      'id': _uuid.v4(),
      'name': b['name'].toString().trim(),
      'description': (b['description'] ?? '').toString(),
      'durationMin': int.tryParse('${b['durationMin']}') ?? 45,
      'price': num.tryParse('${b['price']}') ?? 0,
    };
    db.col('services').add(s);
    db.save();
    return json(s, 201);
  });

  r.delete('/api/services/<id>', (Request req, String id) {
    final denied = guard(req, 'admin');
    if (denied != null) return denied;
    db.col('services').removeWhere((s) => s['id'] == id);
    db.save();
    return json({'ok': true});
  });

  // ---------- Slots ----------
  r.get('/api/slots', (Request req) {
    final date = req.url.queryParameters['date'];
    if (date == null || DateTime.tryParse(date) == null) {
      return json({'error': 'date (YYYY-MM-DD) is required'}, 400);
    }
    final taken = db
        .col('appointments')
        .where((a) => a['date'] == date && a['status'] != 'cancelled')
        .map((a) => a['time'])
        .toSet();
    final now = DateTime.now();
    final free = clinicSlots.where((s) {
      final t = DateTime.tryParse('$date $s:00');
      return !taken.contains(s) && t != null && t.isAfter(now);
    }).toList();
    return json(free);
  });

  // ---------- Appointments ----------
  r.get('/api/appointments', (Request req) {
    final denied = guard(req);
    if (denied != null) return denied;
    final u = userOf(req)!;
    var list = db.col('appointments').toList();
    if (u['role'] != 'admin') {
      list = list.where((a) => a['patientId'] == u['id']).toList();
    }
    list.sort((a, b) =>
        '${b['date']} ${b['time']}'.compareTo('${a['date']} ${a['time']}'));
    return json(list);
  });

  r.post('/api/appointments', (Request req) async {
    final denied = guard(req);
    if (denied != null) return denied;
    final u = userOf(req)!;
    final b = await _body(req);
    final svc = db.col('services').where((s) => s['id'] == b['serviceId']);
    if (svc.isEmpty) return json({'error': 'Choose a service'}, 400);
    final date = '${b['date']}', time = '${b['time']}';
    final when = DateTime.tryParse('$date $time:00');
    if (when == null || !clinicSlots.contains(time) || when.isBefore(DateTime.now())) {
      return json({'error': 'Choose a valid future time slot'}, 400);
    }
    final clash = db.col('appointments').any((a) =>
        a['date'] == date && a['time'] == time && a['status'] != 'cancelled');
    if (clash) return json({'error': 'That slot was just taken. Pick another'}, 409);

    // Admin may book on behalf of a patient.
    var patientId = u['id'];
    if (u['role'] == 'admin' && b['patientId'] != null) patientId = b['patientId'];
    final patient = db.col('users').firstWhere((x) => x['id'] == patientId,
        orElse: () => {});
    if (patient.isEmpty) return json({'error': 'Patient not found'}, 404);

    final appt = {
      'id': _uuid.v4(),
      'patientId': patientId,
      'patientName': patient['name'],
      'serviceId': svc.first['id'],
      'serviceName': svc.first['name'],
      'date': date,
      'time': time,
      'status': 'pending',
      'notes': (b['notes'] ?? '').toString(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    db.col('appointments').add(appt);
    db.save();
    return json(appt, 201);
  });

  r.patch('/api/appointments/<id>/status', (Request req, String id) async {
    final denied = guard(req);
    if (denied != null) return denied;
    final u = userOf(req)!;
    final b = await _body(req);
    final status = '${b['status']}';
    if (!validStatuses.contains(status)) return json({'error': 'Invalid status'}, 400);
    final found = db.col('appointments').where((a) => a['id'] == id);
    if (found.isEmpty) return json({'error': 'Appointment not found'}, 404);
    final appt = found.first;
    if (u['role'] != 'admin') {
      if (appt['patientId'] != u['id']) return json({'error': 'Not your appointment'}, 403);
      if (status != 'cancelled') return json({'error': 'You can only cancel'}, 403);
    }
    appt['status'] = status;
    db.save();
    return json(appt);
  });

  // ---------- Patients (admin) ----------
  r.get('/api/patients', (Request req) {
    final denied = guard(req, 'admin');
    if (denied != null) return denied;
    return json(db.col('users').where((u) => u['role'] == 'patient').map(_pub).toList());
  });

  // ---------- Exercise plans ----------
  r.get('/api/plans', (Request req) {
    final denied = guard(req);
    if (denied != null) return denied;
    final u = userOf(req)!;
    final list = db.col('plans').where((p) => u['role'] == 'admin' || p['patientId'] == u['id']);
    return json(list.toList());
  });

  r.post('/api/plans', (Request req) async {
    final denied = guard(req, 'admin');
    if (denied != null) return denied;
    final b = await _body(req);
    final patient = db.col('users').where((u) => u['id'] == b['patientId']);
    if (patient.isEmpty || (b['title'] ?? '').toString().trim().isEmpty) {
      return json({'error': 'Patient and plan title are required'}, 400);
    }
    final plan = {
      'id': _uuid.v4(),
      'patientId': b['patientId'],
      'patientName': patient.first['name'],
      'title': b['title'].toString().trim(),
      'instructions': (b['instructions'] ?? '').toString(),
      'exercises': b['exercises'] is List ? b['exercises'] : [],
      'createdAt': DateTime.now().toIso8601String(),
    };
    db.col('plans').add(plan);
    db.save();
    return json(plan, 201);
  });

  // ---------- Dashboard stats ----------
  r.get('/api/stats', (Request req) {
    final denied = guard(req, 'admin');
    if (denied != null) return denied;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final appts = db.col('appointments');
    int count(bool Function(Map<String, dynamic>) f) => appts.where(f).length;
    final revenue = appts.where((a) => a['status'] == 'completed').fold<num>(0, (sum, a) {
      final s = db.col('services').where((s) => s['id'] == a['serviceId']);
      return sum + (s.isEmpty ? 0 : (s.first['price'] as num));
    });
    return json({
      'patients': db.col('users').where((u) => u['role'] == 'patient').length,
      'today': count((a) => a['date'] == today && a['status'] != 'cancelled'),
      'pending': count((a) => a['status'] == 'pending'),
      'completed': count((a) => a['status'] == 'completed'),
      'revenue': revenue,
    });
  });

  r.get('/api/health', (Request req) => json({'status': 'ok'}));
  return r;
}
