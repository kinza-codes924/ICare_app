import 'package:flutter/material.dart';

/// Wraps a screen whose library is loaded with a deferred import.
///
/// A deferred import splits that screen (and anything only it uses) into a
/// separate JS chunk that the browser fetches on first navigation instead of
/// downloading with main.dart.js. The catch is that the library's symbols are
/// unusable until `loadLibrary()` has completed, so a deferred route cannot
/// build its screen synchronously the way a normal `builder` does — hence this
/// wrapper. It awaits the load, shows a spinner meanwhile, and then builds.
///
/// Flutter caches the result of `loadLibrary()`, so revisiting a route that was
/// already opened resolves immediately and the spinner never appears again.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.loader,
    required this.builder,
  });

  /// Always pass the generated `<prefix>.loadLibrary` for this screen.
  final Future<void> Function() loader;

  /// Called once the library is in memory. Safe to reference the deferred
  /// prefix's symbols here and nowhere else.
  final Widget Function() builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  // Not `late final`: Retry has to be able to call loader() again, and a
  // final field would hand back the same already-rejected Future forever.
  late Future<void> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // A chunk can fail to load on a flaky connection, or 404 after a
            // redeploy replaced the hashed filenames while the tab stayed
            // open. Offer a reload rather than leaving a dead spinner.
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load this page.',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _future = widget.loader()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return widget.builder();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
