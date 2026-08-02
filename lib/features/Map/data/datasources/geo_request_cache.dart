import 'dart:async';

/// Raised when a map lookup fails in a way worth telling the user about.
///
/// The public OpenStreetMap services are free but rate limited, so a burst of
/// requests can be refused for a short while. That is not a crash and should
/// not be shown as one.
class GeoServiceException implements Exception {
  final String message;

  /// True when the service asked us to slow down (HTTP 429 / 503).
  final bool isRateLimited;

  const GeoServiceException(this.message, {this.isRateLimited = false});

  factory GeoServiceException.fromStatus(int? status, String what) {
    if (status == 429 || status == 503) {
      return GeoServiceException(
        'The free $what service is busy right now. Please wait a few seconds '
        'and try again.',
        isRateLimited: true,
      );
    }
    return GeoServiceException('Could not reach the $what service.');
  }

  @override
  String toString() => message;
}

/// A tiny time-boxed memory cache with a size cap.
///
/// Place coordinates barely change, so repeating the same search during a demo
/// should not cost another network round trip.
class GeoRequestCache<T> {
  final Duration ttl;
  final int maxEntries;

  GeoRequestCache({
    this.ttl = const Duration(minutes: 30),
    this.maxEntries = 60,
  });

  final Map<String, _CacheEntry<T>> _entries = {};

  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _entries.remove(key);
      return null;
    }

    // Refresh recency so the hottest keys survive eviction.
    _entries.remove(key);
    _entries[key] = entry;
    return entry.value;
  }

  void put(String key, T value) {
    _entries.remove(key);
    _entries[key] = _CacheEntry(value, DateTime.now());

    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

class _CacheEntry<T> {
  final T value;
  final DateTime storedAt;

  _CacheEntry(this.value, this.storedAt);
}

/// Thrown by a throttled action that decided it no longer needs to run, e.g.
/// because the user has typed a newer query in the meantime.
class ThrottledRequestSkipped implements Exception {
  const ThrottledRequestSkipped();
}

/// Serialises outgoing calls so we never exceed roughly one request per
/// [minimumGap] — the usage policy for the free Nominatim servers.
class RequestThrottle {
  final Duration minimumGap;

  RequestThrottle({this.minimumGap = const Duration(milliseconds: 1100)});

  Future<void> _tail = Future.value();

  /// Runs [action] once the previous call has finished and the gap has elapsed.
  ///
  /// An action that throws [ThrottledRequestSkipped] sent nothing, so it does
  /// not consume the gap and the next queued call starts immediately.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _tail = _tail.then((_) async {
      var didSend = true;
      try {
        completer.complete(await action());
      } on ThrottledRequestSkipped catch (error, stackTrace) {
        didSend = false;
        completer.completeError(error, stackTrace);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }

      // Hold the queue open for the mandated gap before the next call starts.
      if (didSend) await Future<void>.delayed(minimumGap);
    });

    return completer.future;
  }
}
