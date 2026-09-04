// Custom bootstrap — deliberately does NOT register Flutter's service worker.
//
// The generated bootstrap registers one, and that worker serves main.dart.js
// from its own cache ahead of the network. Nginx already sends
// `Cache-Control: no-store, no-cache` for every asset, but the worker sits in
// front of that, so a freshly deployed build kept loading as the old one —
// repeatedly, across several deploys, with no way for a user to tell that the
// upload had in fact worked. index.html carries an unregister script, but it
// runs before the generated bootstrap re-registers the worker, so it could
// never win. Not registering one at all is what actually fixes it.
//
// flutter_build_config still carries serviceWorkerSettings, so blank it out
// after it is applied: loadServiceWorker() returns early when its settings
// argument is falsy, which is what stops the registration.
//
// The cost is no offline support, which this app never relied on: every
// screen needs the API anyway.
{{flutter_js}}
{{flutter_build_config}}

if (typeof _flutter !== 'undefined' && _flutter.buildConfig) {
  _flutter.buildConfig.serviceWorkerSettings = null;
}

_flutter.loader.load({
  serviceWorkerSettings: null,
});
