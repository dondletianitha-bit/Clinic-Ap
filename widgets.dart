import 'package:flutter/material.dart';

const kTeal = Color(0xFF0F5F66);
const kSand = Color(0xFFF4F7F6);
const kAmber = Color(0xFFE9A23B);

/// Loads data once, shows spinner / error / retry, and exposes a reload callback.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f = widget.load();
  void _reload() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${s.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Try again')),
              ]),
            );
          }
          return widget.builder(c, s.data as T, _reload);
        },
      );
}

void toast(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red.shade700 : kTeal,
  ));
}

/// Centers content with a readable max width on wide web screens.
class Page extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Page({super.key, required this.child, this.maxWidth = 900});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      );
}

Color statusColor(String s) => switch (s) {
      'confirmed' => Colors.blue.shade700,
      'completed' => Colors.green.shade700,
      'cancelled' => Colors.red.shade700,
      _ => Colors.orange.shade800,
    };

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Chip(
        label: Text(status, style: TextStyle(color: statusColor(status), fontWeight: FontWeight.w600)),
        backgroundColor: statusColor(status).withOpacity(0.1),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
}
