import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [connectivity_plus] v5.0.x and exposes a single [isOnline] boolean.
///
/// v5.0.x API: both [checkConnectivity()] and [onConnectivityChanged]
/// return/emit a single [ConnectivityResult] (not a List — that was v6.x).
///
/// Uses [Future.microtask] around [notifyListeners] so notifications never
/// fire inside the widget build phase.
class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true; // optimistic default until first real check
  StreamSubscription<ConnectivityResult>? _subscription;

  bool get isOnline => _isOnline;

  /// Invoked each time the device transitions from offline → online.
  /// Register a single callback here to trigger pending-draft uploads.
  VoidCallback? onCameOnline;

  /// Call once from [main()] before [runApp].
  Future<void> init() async {
    // v5.0.x returns a single ConnectivityResult
    final initial = await Connectivity().checkConnectivity();
    _isOnline = _isConnected(initial);

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final online = _isConnected(result);
      if (online != _isOnline) {
        final wasOffline = !_isOnline;
        _isOnline = online;
        Future.microtask(notifyListeners);
        // Fire the callback when going from offline → online
        if (online && wasOffline) {
          onCameOnline?.call();
        }
      }
    });
  }

  bool _isConnected(ConnectivityResult result) =>
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
