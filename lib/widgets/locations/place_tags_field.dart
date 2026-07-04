/// Tag selector for a place, styled like the papertrail tag section.
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

/// A wrap of FilterChips for selecting tags plus an "Add" action chip for
/// entering a custom tag. Mirrors the tag layout used in papertrail.
///
/// [options] is the full set to display (defaults + used + already selected),
/// [selected] is the current selection. Toggling and adding are reported via
/// callbacks so the parent owns the state.

class PlaceTagsField extends StatelessWidget {
  const PlaceTagsField({
    super.key,
    this.title = 'Tags',
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onAddCustom,
  });

  final String title;
  final Set<String> options;
  final Set<String> selected;
  final void Function(String tag, bool selected) onToggle;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final sorted = options.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...sorted.map(
              (tag) => FilterChip(
                label: Text(tag),
                selected: selected.contains(tag),
                onSelected: (sel) => onToggle(tag, sel),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: onAddCustom,
            ),
          ],
        ),
      ],
    );
  }
}

/// Prompts for a custom tag name and returns it (trimmed) or null if cancelled
/// or empty.

Future<String?> promptForCustomTag(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add tag'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Favourite'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  final tag = value?.trim();
  return (tag != null && tag.isNotEmpty) ? tag : null;
}
