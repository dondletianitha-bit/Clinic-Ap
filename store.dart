import 'dart:convert';
import 'dart:io';

/// Tiny JSON-file database. Perfect for a first client / demo.
/// For scale, replace with PostgreSQL (package:postgres) behind the same
/// `col()` / `save()` calls used in routes.dart.
class Store {
  final File _file;
  final Map<String, List<Map<String, dynamic>>> _data = {
    'users': [],
    'services': [],
    'appointments': [],
    'plans': [],
  };

  Store(String path) : _file = File(path) {
    if (_file.existsSync()) {
      final j = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      for (final k in _data.keys) {
        _data[k] = ((j[k] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
  }

  List<Map<String, dynamic>> col(String name) => _data[name]!;
  void save() => _file.writeAsStringSync(jsonEncode(_data));
}
