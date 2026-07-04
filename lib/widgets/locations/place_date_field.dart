/// Optional, clearable date-of-interest field for a place.
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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
/// Authors: Graham Williams

library;

import 'package:flutter/material.dart';

/// Shows the currently selected [value] (or "No date set"), with a Pick button
/// that opens a date picker and a clear button when a date is set. Reports the
/// chosen date (or null on clear) via [onChanged].

class PlaceDateField extends StatelessWidget {
  const PlaceDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Date of interest (optional)',
        prefixIcon: Icon(Icons.event_outlined),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'No date set' : _format(value!),
              style: TextStyle(
                color: value == null ? Theme.of(context).hintColor : null,
              ),
            ),
          ),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Clear date',
              onPressed: () => onChanged(null),
            ),
          TextButton(
            onPressed: () => _pick(context),
            child: const Text('Pick'),
          ),
        ],
      ),
    );
  }
}
