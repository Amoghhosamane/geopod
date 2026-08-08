/// Place save handler for optimistic saving with background updates.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:solidpod/solidpod.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/utils/ui_utils.dart';
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/geomap.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';

/// Shows a saving snackbar for optimistic save.

void showSavingSnackbar(BuildContext context, Place place) {
  SnackBarHelper.showLoading(context, 'Saving "${place.displayTitle}"...');
}

/// Shows a success snackbar after place is saved.

void showSaveSuccessSnackbar(BuildContext context) {
  SnackBarHelper.showSuccess(context, 'Place saved successfully!');
}

/// Performs background save of a place with address lookup.
/// Note: Context is passed through to PlacesService which handles mounted checks internally.
/// If [encrypted] is true, saves to encrypted storage.

Future<Place?> performBackgroundSave(
  Place originalPlace,
  BuildContext context, {
  // Required rather than defaulting to false: omitting it silently wrote to
  // the plain track, which is how adds from the Locations page ended up
  // unencrypted while the same form from the map did not.
  required bool encrypted,
}) async {
  final address = await GeocodingService.getAddress(
    originalPlace.lat,
    originalPlace.lng,
  );
  final updatedPlace = originalPlace.copyWith(
    address: address,
    isEncrypted: encrypted,
  );
  if (!context.mounted) return null;

  bool success;
  if (encrypted) {
    // Save to encrypted storage.
    success = await EncryptedPlacesService.addEncryptedPlace(
      updatedPlace,
      context,
      const GeoMapWidget(),
    );
  } else {
    // Save to regular storage.
    success = await PlacesService.addPlace(
      updatedPlace,
      context,
      const GeoMapWidget(),
    );
  }

  if (success) {
    return updatedPlace;
  } else {
    throw Exception(encrypted ? 'Encrypted save failed' : 'WritePod failed');
  }
}

/// Shows the add place dialog, which persists the new place through [onSave].
/// Does nothing if the user is not logged in or cancels.
///
/// [onSave] receives the AddPlaceResult with place and encryption flag, and
/// must not complete until the Pod write has finished — the form awaits it so
/// that closing the window cannot kill the write mid-flight.

Future<void> showAddPlaceDialogIfLoggedIn({
  required BuildContext context,
  required Future<void> Function(AddPlaceResult) onSave,
  double? latitude,
  double? longitude,
  Set<String> knownTags = const {},
}) async {
  final webId = await getWebId();
  if (webId == null || webId.isEmpty) {
    if (!context.mounted) return;
    await showLoginRequiredDialog(context);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AddPlaceForm(
      initialLatitude: latitude,
      initialLongitude: longitude,
      returnWidget: const GeoMapWidget(),
      knownTags: knownTags,
      onSave: onSave,
    ),
  );
}

// Track ongoing zoom animation to prevent conflicts.
bool _isZoomAnimating = false;

/// Zoom in the map by a fixed amount with smooth animation.

void zoomIn(MapController mapController) {
  // Ignore clicks while animation is running.
  if (_isZoomAnimating) return;
  _animateZoom(mapController, 0.8);
}

/// Zoom out the map by a fixed amount with smooth animation.

void zoomOut(MapController mapController) {
  // Ignore clicks while animation is running.
  if (_isZoomAnimating) return;
  _animateZoom(mapController, -0.8);
}

/// Helper function to animate zoom changes smoothly.

void _animateZoom(MapController mapController, double delta) async {
  _isZoomAnimating = true;

  final startZoom = mapController.camera.zoom;
  final targetZoom = (startZoom + delta).clamp(3.0, 18.0);
  final center = mapController.camera.center;

  // Number of steps for smooth animation
  const steps = 30;
  const duration = Duration(milliseconds: 120);
  final stepDelay = duration.inMilliseconds ~/ steps;

  for (int i = 1; i <= steps; i++) {
    // Ease-in-out curve approximation
    final t = i / steps;
    final eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

    final currentZoom = startZoom + (targetZoom - startZoom) * eased;
    mapController.move(center, currentZoom);

    if (i < steps) {
      await Future.delayed(Duration(milliseconds: stepDelay));
    }
  }

  _isZoomAnimating = false;
}
