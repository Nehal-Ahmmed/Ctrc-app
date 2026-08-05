import 'dart:async';

class GeoServiceException implements Exception {
  final String message;

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

class ThrottledRequestSkipped implements Exception {
  const ThrottledRequestSkipped();
}

class RequestThrottle {
  final Duration minimumGap;

  RequestThrottle({this.minimumGap = const Duration(milliseconds: 1100)});

  Future<void> _tail = Future.value();

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

      if (didSend) await Future<void>.delayed(minimumGap);
    });

    return completer.future;
  }
}
