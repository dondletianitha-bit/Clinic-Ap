import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:physio_backend/auth.dart';
import 'package:physio_backend/routes.dart';
import 'package:physio_backend/store.dart';

Future<void> main() async {
  final db = Store(Platform.environment['DB_FILE'] ?? 'data.json');
  seed(db);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(authMiddleware())
      .addHandler(buildRouter(db).call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Physio API running on http://localhost:${server.port}');
  print('Default admin: admin@clinic.com / Admin@123  (change after first login!)');
}
