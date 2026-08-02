/// How the feed is narrowed down and ordered.
///
/// Nothing in here is applied on the device. Every field turns into a query
/// parameter and the work is done by the sql that builds the feed — sorting the
/// reports already in hand would only reorder the slice that came back, which
/// is not the same list as the one the chosen order actually asks for.
library;

/// Orders the backend knows how to serve. [key] is the exact value sent as the
/// `sort` parameter and matched against the fixed list on the server.
enum FeedSort {
  nearest('nearest'),
  newest('newest'),
  oldest('oldest'),
  top('top'),
  discussed('discussed'),
  confirmed('confirmed');

  const FeedSort(this.key);

  final String key;
}

/// Whether the community has backed a report up. Worked out by a database
/// trigger, so these are the only three values a report can carry.
enum FeedStatus {
  any(null),
  verified('verified'),
  unverified('unverified'),
  disputed('disputed');

  const FeedStatus(this.key);

  final String? key;
}

/// How the reporter knew about the incident.
enum FeedEvidence {
  any(null),
  seen('seen'),
  heard('heard'),
  guessed('guessed');

  const FeedEvidence(this.key);

  final String? key;
}

/// How far back the feed reaches.
enum FeedAge {
  any(null),
  lastHour(1),
  last6Hours(6),
  lastDay(24),
  lastWeek(24 * 7);

  const FeedAge(this.hours);

  final int? hours;
}

class FeedFilter {
  const FeedFilter({
    this.sort = FeedSort.nearest,
    this.status = FeedStatus.any,
    this.evidence = FeedEvidence.any,
    this.age = FeedAge.any,
    this.withPhotoOnly = false,
  });

  /// Closest first with nothing filtered out — what the feed opens with.
  static const FeedFilter initial = FeedFilter();

  final FeedSort sort;
  final FeedStatus status;
  final FeedEvidence evidence;
  final FeedAge age;
  final bool withPhotoOnly;

  FeedFilter copyWith({
    FeedSort? sort,
    FeedStatus? status,
    FeedEvidence? evidence,
    FeedAge? age,
    bool? withPhotoOnly,
  }) {
    return FeedFilter(
      sort: sort ?? this.sort,
      status: status ?? this.status,
      evidence: evidence ?? this.evidence,
      age: age ?? this.age,
      withPhotoOnly: withPhotoOnly ?? this.withPhotoOnly,
    );
  }

  /// How many reports are being held back. Drives the badge on the filter
  /// button; the sort order is left out because it hides nothing.
  int get activeFilterCount => [
        status != FeedStatus.any,
        evidence != FeedEvidence.any,
        age != FeedAge.any,
        withPhotoOnly,
      ].where((active) => active).length;

  bool get isDefault =>
      sort == FeedSort.nearest && activeFilterCount == 0;

  /// How the filter is stored on the device between launches.
  ///
  /// Enum names rather than the wire keys: `sort` and `status` already send
  /// their own strings to the backend, and tying stored data to those would
  /// mean a server-side rename silently reset everybody's saved filter.
  Map<String, dynamic> toJson() => {
        'sort': sort.name,
        'status': status.name,
        'evidence': evidence.name,
        'age': age.name,
        'withPhotoOnly': withPhotoOnly,
      };

  /// Reads back [toJson]. Anything unrecognised falls back to the default for
  /// that field, so a filter saved by an older build still opens.
  factory FeedFilter.fromJson(Map<String, dynamic> json) {
    T restore<T extends Enum>(List<T> values, Object? name, T fallback) {
      return values.firstWhere(
        (value) => value.name == name,
        orElse: () => fallback,
      );
    }

    return FeedFilter(
      sort: restore(FeedSort.values, json['sort'], FeedSort.nearest),
      status: restore(FeedStatus.values, json['status'], FeedStatus.any),
      evidence: restore(FeedEvidence.values, json['evidence'], FeedEvidence.any),
      age: restore(FeedAge.values, json['age'], FeedAge.any),
      withPhotoOnly: json['withPhotoOnly'] == true,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
        'sort': sort.key,
        if (status.key != null) 'status': status.key,
        if (evidence.key != null) 'evidence': evidence.key,
        if (age.hours != null) 'withinHours': age.hours,
        if (withPhotoOnly) 'withPhoto': true,
      };

  @override
  bool operator ==(Object other) =>
      other is FeedFilter &&
      other.sort == sort &&
      other.status == status &&
      other.evidence == evidence &&
      other.age == age &&
      other.withPhotoOnly == withPhotoOnly;

  @override
  int get hashCode => Object.hash(sort, status, evidence, age, withPhotoOnly);
}
