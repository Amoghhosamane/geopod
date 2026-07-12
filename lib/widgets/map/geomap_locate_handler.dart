/// Locate-button handling for GeoMap.
///
// Time-stamp: <Sunday 2026-07-12 +1000>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/location_service.dart';

/// Handles the locate (my location) floating button.

mixin GeoMapLocateHandler<T extends StatefulWidget> on State<T> {
  MapController get mapController;
  bool get isLocating;
  set isLocating(bool value);
  set userLocation(LatLng? value);

  /// Handle location button tap - get user location and move map to it.

  Future<void> onLocatePressed() async {
    if (isLocating) return;

    setState(() => isLocating = true);

    try {
      final result = await LocationService.getCurrentLocation();

      if (!mounted) return;

      if (result.success && result.location != null) {
        // Save user location and move map to it.
        setState(() {
          userLocation = result.location;
        });
        mapController.move(result.location!, 15.0);

        // Show success message.

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show detailed error message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? 'Unable to get your location',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLocating = false);
      }
    }
  }
}
