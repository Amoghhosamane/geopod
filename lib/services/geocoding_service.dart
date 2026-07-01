/// Geocoding service using OpenStreetMap Nominatim API.
///
// Time-stamp: <2025-12-04 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for reverse geocoding coordinates to human-readable addresses.
///
/// Uses OpenStreetMap's Nominatim API which is free and works on both
/// Web and Desktop platforms without requiring any API keys.

class GeocodingService {
  /// Nominatim API endpoint for reverse geocoding.
  static const String _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/reverse';

  /// Photon API endpoint for forward geocoding (search). Photon is an
  /// OpenStreetMap-based geocoder with typo tolerance and search-as-you-type,
  /// so it handles minor misspellings that Nominatim would reject.
  static const String _photonSearchEndpoint = 'https://photon.komoot.io/api/';

  /// User-Agent header required by Nominatim API.

  static const String _userAgent = 'GeopodApp/1.0 (Flutter)';

  /// Searches for a typed address, place name or landmark and returns matching
  /// locations, best match first.
  ///
  /// Returns an empty list on error or when nothing is found.

  static Future<List<GeocodeResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$_photonSearchEndpoint?q=${Uri.encodeQueryComponent(q)}'
        '&limit=8&lang=en',
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        return features
            .whereType<Map<String, dynamic>>()
            .map(GeocodeResult.fromPhotonFeature)
            .whereType<GeocodeResult>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Converts latitude/longitude coordinates to a human-readable address.
  ///
  /// Returns "Address not found" if the request fails or no address is found.
  /// Always returns addresses in English.

  static Future<String> getAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_nominatimEndpoint?format=json&lat=$lat&lon=$lng'
        '&zoom=18&addressdetails=1&accept-language=en',
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;

        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }

      return 'Address not found';
    } catch (_) {
      return 'Address not found';
    }
  }

  /// Gets a shortened version of the address (city, state, country).
  ///
  /// This extracts key parts from the full address for display in limited space.

  static Future<String> getShortAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_nominatimEndpoint?format=json&lat=$lat&lon=$lng'
        '&zoom=14&addressdetails=1&accept-language=en',
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parts = <String>[];

          final suburb =
              address['suburb'] ?? address['city'] ?? address['town'];
          if (suburb != null) parts.add(suburb as String);

          final state = address['state'];
          if (state != null) parts.add(state as String);

          final country = address['country'];
          if (country != null) parts.add(country as String);

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          if (displayName.length > 50) {
            return '${displayName.substring(0, 47)}...';
          }
          return displayName;
        }
      }

      return 'Unknown location';
    } catch (_) {
      return 'Unknown location';
    }
  }
}

/// A single forward-geocoding search result.

class GeocodeResult {
  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });

  final double lat;
  final double lng;

  /// Full human-readable name/address of the match.
  final String displayName;

  /// A shorter label: the first component of the display name.
  String get shortName => displayName.split(',').first.trim();

  /// Builds a result from a Photon GeoJSON feature. Photon has no single
  /// display-name field, so compose one from the address properties. Note that
  /// GeoJSON coordinates are [longitude, latitude] (lon first).

  static GeocodeResult? fromPhotonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return null;
    final lng = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final props = feature['properties'] as Map<String, dynamic>? ?? {};

    String? str(String key) {
      final v = props[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    // Compose a readable address from the available components, in order and
    // without duplicates, matching how the display name reads for a place.
    final name = str('name');
    final houseAndStreet = [
      str('housenumber'),
      str('street'),
    ].whereType<String>().join(' ');

    final parts = <String>[
      ?name,
      if (houseAndStreet.isNotEmpty) houseAndStreet,
      if (str('district') != null) str('district')!,
      if (str('city') != null) str('city')!,
      if (str('county') != null) str('county')!,
      if (str('postcode') != null) str('postcode')!,
      if (str('state') != null) str('state')!,
      if (str('country') != null) str('country')!,
    ];

    // De-duplicate consecutive equal parts (e.g. name == city for a city).
    final deduped = <String>[];
    for (final p in parts) {
      if (deduped.isEmpty || deduped.last != p) deduped.add(p);
    }

    final displayName = deduped.isEmpty
        ? 'Unknown location'
        : deduped.join(', ');

    return GeocodeResult(lat: lat, lng: lng, displayName: displayName);
  }
}
