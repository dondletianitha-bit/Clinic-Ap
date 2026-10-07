import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

final String _secret =
    Platform.environment['JWT_SECRET'] ?? 'change-me-in-production';

Response json(Object data, [int status = 200]) => Response(status,
    body: jsonEncode(data), headers: {'content-type': 'application/json'});

String signToken(Map<String, dynamic> user) =>
    JWT({'id': user['id'], 'role': user['role']})
        .sign(SecretKey(_secret), expiresIn: const Duration(days: 7));

/// Reads the Bearer token (if any) and puts the payload in request context.
Middleware authMiddleware() => (inner) => (req) {
      final h = req.headers['authorization'];
      if (h != null && h.startsWith('Bearer ')) {
        try {
          final jwt = JWT.verify(h.substring(7), SecretKey(_secret));
          return inner(req.change(context: {'user': jwt.payload}));
        } catch (_) {}
      }
      return inner(req);
    };

Map<String, dynamic>? userOf(Request r) =>
    (r.context['user'] as Map?)?.cast<String, dynamic>();

/// Returns an error Response if the caller is not allowed, otherwise null.
Response? guard(Request r, [String? role]) {
  final u = userOf(r);
  if (u == null) return json({'error': 'Please log in first'}, 401);
  if (role != null && u['role'] != role) {
    return json({'error': 'You do not have access to this'}, 403);
  }
  return null;
}
