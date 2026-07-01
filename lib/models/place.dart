/// Data model representing a saved place.
///
// Time-stamp: <2026-06-20 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Data model representing a saved place.

class Place {
  final String id;
  final double lat;
  final double lng;

  /// Short title shown in lists and map markers.
  final String title;

  /// Markdown-formatted notes about this place.
  final String note;

  final String timestamp;
  final String? address;

  /// Optional user-specified date of interest for this place (ISO-8601 date,
  /// e.g. '2026-07-01'). Null when not set.
  final String? dateOfInterest;

  /// User tags for categorising this place.
  final List<String> tags;

  /// Whether this place is from local assets (canned examples).
  final bool isLocal;

  /// Whether this place is stored encrypted.
  final bool isEncrypted;

  Place({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    required this.note,
    required this.timestamp,
    this.address,
    this.dateOfInterest,
    this.tags = const [],
    this.isLocal = false,
    this.isEncrypted = false,
  });

  /// Creates a Place from JSON map.
  ///
  /// [isLocalSource] indicates if the JSON comes from local assets.
  /// For backwards compatibility, falls back to [note] as title when
  /// no [title] field is present.

  factory Place.fromJson(
    Map<String, dynamic> json, {
    bool isLocalSource = false,
    bool isEncryptedSource = false,
  }) {
    final note = json['note'] as String? ?? '';
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];
    return Place(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      title: json['title'] as String? ?? note,
      note: note,
      timestamp: json['timestamp'] as String? ?? '',
      address: json['address'] as String?,
      dateOfInterest: json['dateOfInterest'] as String?,
      tags: tags,
      isLocal: isLocalSource,
      isEncrypted: isEncryptedSource,
    );
  }

  /// Converts Place to JSON map.

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'title': title,
      'note': note,
      'timestamp': timestamp,
      if (address != null) 'address': address,
      if (dateOfInterest != null) 'dateOfInterest': dateOfInterest,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  /// Short label used in map markers, list tiles, and sheet headers.

  String get displayTitle => title.isNotEmpty ? title : '(No title)';

  /// Returns formatted coordinates string.

  String get coordinates =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  /// Returns the address or coordinates if address is not available.

  String get displayAddress => address ?? coordinates;

  /// Returns a short version of the address for display in limited space.

  String get shortAddress {
    if (address == null || address!.isEmpty) return coordinates;
    if (address!.length > 40) return '${address!.substring(0, 37)}...';
    return address!;
  }

  /// Returns formatted date string.

  String get formattedDate {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  /// Creates a copy of this Place with optional field overrides.

  Place copyWith({
    String? id,
    double? lat,
    double? lng,
    String? title,
    String? note,
    String? timestamp,
    String? address,
    String? dateOfInterest,
    bool clearDateOfInterest = false,
    List<String>? tags,
    bool? isLocal,
    bool? isEncrypted,
  }) {
    return Place(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      title: title ?? this.title,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      dateOfInterest: clearDateOfInterest
          ? null
          : (dateOfInterest ?? this.dateOfInterest),
      tags: tags ?? this.tags,
      isLocal: isLocal ?? this.isLocal,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  /// Formatted date of interest (YYYY-MM-DD) or null when not set.

  String? get formattedDateOfInterest {
    final d = dateOfInterest;
    if (d == null || d.isEmpty) return null;
    try {
      final date = DateTime.parse(d);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return d;
    }
  }
}
