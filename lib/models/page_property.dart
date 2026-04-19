/// Types of structured properties that can be attached to a [FolioPage].
enum PagePropertyType {
  text,
  number,
  date,
  select,
  status,
  url,
  checkbox,
}

extension PagePropertyTypeLabel on PagePropertyType {
  String get defaultName {
    switch (this) {
      case PagePropertyType.text:
        return 'Text';
      case PagePropertyType.number:
        return 'Number';
      case PagePropertyType.date:
        return 'Date';
      case PagePropertyType.select:
        return 'Select';
      case PagePropertyType.status:
        return 'Status';
      case PagePropertyType.url:
        return 'URL';
      case PagePropertyType.checkbox:
        return 'Checkbox';
    }
  }
}

/// A single structured property attached to a page (frontmatter).
///
/// [value] semantics by type:
/// - text → String
/// - number → double (stored as-is; serialized as num)
/// - date → int (milliseconds since epoch, like all other timestamps in Folio)
/// - select → String (the selected option label)
/// - status → String (the selected status label)
/// - url → String
/// - checkbox → bool
///
/// [options] is only relevant for [PagePropertyType.select] and
/// [PagePropertyType.status]. For status, default options are provided
/// via [FolioPageProperty.defaultStatusOptions].
class FolioPageProperty {
  FolioPageProperty({
    required this.id,
    required this.name,
    required this.type,
    this.value,
    List<String>? options,
  }) : options = options ??
            (type == PagePropertyType.status
                ? List<String>.from(defaultStatusOptions)
                : const []);

  final String id;
  String name;
  PagePropertyType type;

  /// The stored value. May be null when not yet set.
  dynamic value;

  /// Valid option labels (for select / status).
  List<String> options;

  static const List<String> defaultStatusOptions = [
    'Not started',
    'In progress',
    'Done',
  ];

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{'id': id, 'name': name, 'type': type.name};
    if (value != null) j['value'] = value;
    if (options.isNotEmpty) j['options'] = List<String>.from(options);
    return j;
  }

  factory FolioPageProperty.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'text';
    final type = PagePropertyType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => PagePropertyType.text,
    );
    return FolioPageProperty(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      type: type,
      value: j['value'],
      options: (j['options'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList(growable: true) ??
          (type == PagePropertyType.status
              ? List<String>.from(FolioPageProperty.defaultStatusOptions)
              : []),
    );
  }
}
