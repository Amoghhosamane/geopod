/// Dialog for editing a place's title, note, and coordinates.
///
// Time-stamp: <2026-06-20 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:emacs_text_field/emacs_text_field.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/constants/place_tags.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/widgets/locations/place_date_field.dart';
import 'package:geopod/widgets/locations/place_tags_field.dart';

/// Dialog for editing a place's title, note, and coordinates.

class EditPlaceDialog extends StatefulWidget {
  const EditPlaceDialog({
    super.key,
    required this.place,
    this.knownTags = const {},
    this.onSave,
  });

  final Place place;

  /// Tags already used across saved places, merged with defaults for the
  /// tag selector.
  final Set<String> knownTags;

  /// Persists the edited place.  The caller owns the optimistic list update,
  /// the Pod write, and the success/failure feedback.
  ///
  /// Returns a future that completes when the Pod write is done.  It MUST be
  /// awaited by the caller's implementation: closing the app window waits on
  /// this before quitting, so a fire-and-forget write would be killed
  /// mid-flight and the edit silently lost.
  final Future<void> Function(Place)? onSave;

  @override
  State<EditPlaceDialog> createState() => _EditPlaceDialogState();
}

class _EditPlaceDialogState extends State<EditPlaceDialog>
    with UnsavedChangesMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPreview = false;
  String? _previewAddress;

  /// True while a save is in flight, so Save stays disabled without having to
  /// pretend the edit is already saved.
  bool _saving = false;

  // Snapshot of the last-saved state — used to compute _hasChanges.
  late String _initTitle;
  late String _initLat;
  late String _initLng;
  late String _initNote;
  String? _initAddress;
  String? _initDate;
  late Set<String> _initTags;

  // Optional date of interest and tags for this place.
  DateTime? _dateOfInterest;
  late final Set<String> _tags;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.place.title);
    _latController = TextEditingController(
      text: widget.place.lat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.place.lng.toStringAsFixed(6),
    );
    _noteController = TextEditingController(text: widget.place.note);
    _previewAddress = widget.place.address;
    _tags = {...widget.place.tags};
    final doi = widget.place.dateOfInterest;
    if (doi != null && doi.isNotEmpty) {
      _dateOfInterest = DateTime.tryParse(doi);
    }
    _snapshotSavedState();
    for (final c in [
      _titleController,
      _latController,
      _lngController,
      _noteController,
    ]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  /// Snapshot the current field values as the last-saved baseline.

  void _snapshotSavedState() {
    _initTitle = _titleController.text;
    _initLat = _latController.text;
    _initLng = _lngController.text;
    _initNote = _noteController.text;
    _initAddress = _previewAddress;
    _initDate = _dateOfInterest?.toIso8601String();
    _initTags = {..._tags};
  }

  bool get _hasChanges =>
      _titleController.text != _initTitle ||
      _latController.text != _initLat ||
      _lngController.text != _initLng ||
      _noteController.text != _initNote ||
      _previewAddress != _initAddress ||
      _dateChanged ||
      _tagsChanged;

  bool get _dateChanged => _dateOfInterest?.toIso8601String() != _initDate;

  bool get _tagsChanged =>
      _initTags.length != _tags.length || !_initTags.containsAll(_tags);

  /// The latitude currently entered, or null when it is not a valid value.

  double? get _lat {
    final v = double.tryParse(_latController.text);
    return (v == null || v < -90 || v > 90) ? null : v;
  }

  /// The longitude currently entered, or null when it is not a valid value.

  double? get _lng {
    final v = double.tryParse(_lngController.text);
    return (v == null || v < -180 || v > 180) ? null : v;
  }

  // The window-close prompt comes from UnsavedChangesMixin, which needs to
  // know what counts as unsaved and how to save it.

  @override
  bool get hasUnsavedChanges => _hasChanges;

  @override
  bool get canSaveUnsavedChanges =>
      _titleController.text.trim().isNotEmpty && _lat != null && _lng != null;

  @override
  Future<bool> saveUnsavedChanges() => _save();

  Future<void> _addCustomTag() async {
    final tag = await promptForCustomTag(context);
    if (tag != null) setState(() => _tags.add(tag));
  }

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _latController,
      _lngController,
      _noteController,
    ]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _previewAddressForCoordinates() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
    setState(() => _isLoading = true);
    final address = await GeocodingService.getAddress(lat, lng);
    if (mounted) {
      setState(() {
        _previewAddress = address;
        _isLoading = false;
      });
    }
  }

  /// Persists the edit through [EditPlaceDialog.onSave].  Never pops: the
  /// window-close path keeps the dialog in place while the window goes away.
  ///
  /// Returns whether the edit actually reached the Pod.

  Future<bool> _save() async {
    final lat = _lat;
    final lng = _lng;
    // Nothing writable yet, so nothing has been saved.
    if (lat == null || lng == null) return false;
    final updated = widget.place.copyWith(
      title: _titleController.text.trim(),
      lat: lat,
      lng: lng,
      note: _noteController.text,
      timestamp: DateTime.now().toIso8601String(),
      address: widget.place.address,
      dateOfInterest: _dateOfInterest?.toIso8601String(),
      clearDateOfInterest: _dateOfInterest == null,
      tags: _tags.toList()..sort(),
    );
    setState(() => _saving = true);
    try {
      // Awaited so a window close can wait for the Pod write to complete.
      await widget.onSave?.call(updated);
      // Snapshot only once the write has actually landed. Marking the edit
      // saved on a failed write would disable Save and stop the window-close
      // prompt firing, losing the edit the user asked to keep.
      if (mounted) setState(_snapshotSavedState);

      return true;
    } catch (e) {
      SolidWriteFailures.report('Failed saving the place.\n\n$e');

      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Save from the Save button, then close the dialog.

  Future<void> _saveAndClose() async {
    if (!_formKey.currentState!.validate()) return;
    // Close only once the write has landed. A failed write leaves the dialog
    // open with the user's edits still in it.
    final saved = await _save();
    if (mounted && saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          Gap(8),
          Expanded(child: Text('Edit Place')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title.
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Short name for this place',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const Gap(16),

                // Note — editor / preview toggle.
                Row(
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showPreview = !_showPreview),
                      icon: Icon(
                        _showPreview ? Icons.edit : Icons.preview,
                        size: 16,
                      ),
                      label: Text(_showPreview ? 'Edit' : 'Preview'),
                    ),
                  ],
                ),
                const Gap(4),
                _showPreview
                    ? Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _noteController.text.isEmpty
                            ? Text(
                                'No notes yet.',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Markdown(
                                data: _noteController.text,
                                shrinkWrap: true,
                              ),
                      )
                    : SizedBox(
                        height: 200,
                        child: EmacsTextField(
                          controller: _noteController,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Markdown notes about this place…',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                const Gap(16),

                // Coordinates.
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '-90 to 90',
                          prefixIcon: Icon(Icons.north),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lat = double.tryParse(v);
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '-180 to 180',
                          prefixIcon: Icon(Icons.east),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lng = double.tryParse(v);
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const Gap(12),
                    IconButton.outlined(
                      onPressed: _isLoading
                          ? null
                          : _previewAddressForCoordinates,
                      tooltip: 'Preview address',
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_searching, size: 18),
                    ),
                  ],
                ),
                const Gap(12),

                // Address preview.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        _previewAddress ?? 'Address not available',
                        style: TextStyle(
                          fontSize: 13,
                          color: _previewAddress != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                          fontStyle: _previewAddress != null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Address updates automatically when coordinates change.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),

                // Date of interest (optional, clearable).
                const Gap(16),
                PlaceDateField(
                  value: _dateOfInterest,
                  onChanged: (d) => setState(() => _dateOfInterest = d),
                ),

                // Tags (papertrail-style chips).
                const Gap(16),
                PlaceTagsField(
                  options: {...defaultPlaceTags, ...widget.knownTags, ..._tags},
                  selected: _tags,
                  onToggle: (tag, sel) => setState(() {
                    sel ? _tags.add(tag) : _tags.remove(tag);
                  }),
                  onAddCustom: _addCustomTag,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: (_isLoading || _saving || !_hasChanges)
              ? null
              : _saveAndClose,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
