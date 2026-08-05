library;

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

enum FeedStatus {
  any(null),
  verified('verified'),
  unverified('unverified'),
  disputed('disputed');

  const FeedStatus(this.key);

  final String? key;
}

enum FeedEvidence {
  any(null),
  seen('seen'),
  heard('heard'),
  guessed('guessed');

  const FeedEvidence(this.key);

  final String? key;
}

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

  int get activeFilterCount => [
        status != FeedStatus.any,
        evidence != FeedEvidence.any,
        age != FeedAge.any,
        withPhotoOnly,
      ].where((active) => active).length;

  bool get isDefault =>
      sort == FeedSort.nearest && activeFilterCount == 0;

  Map<String, dynamic> toJson() => {
        'sort': sort.name,
        'status': status.name,
        'evidence': evidence.name,
        'age': age.name,
        'withPhotoOnly': withPhotoOnly,
      };

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
