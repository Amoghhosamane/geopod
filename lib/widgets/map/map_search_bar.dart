/// Search bar overlay for finding an address or landmark on the map.
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

import 'package:geopod/services/geocoding_service.dart';

/// A search field pinned near the top of the map. Typing an address, place
/// name or landmark and submitting shows matching locations; picking one
/// calls [onSelect] with that result (the map should move there and offer to
/// save it).

class MapSearchBar extends StatefulWidget {
  const MapSearchBar({super.key, required this.onSelect});

  /// Called when the user picks a search result.
  final void Function(GeocodeResult result) onSelect;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<GeocodeResult> _results = [];
  bool _searching = false;
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _expanded = true;
    });
    final results = await GeocodingService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _results = [];
      _expanded = false;
    });
  }

  void _pick(GeocodeResult result) {
    // Keep whatever the user typed in the field; only collapse the results.
    // (Overwriting with the result name dropped trailing words of the query.)
    setState(() {
      _expanded = false;
      _results = [];
    });
    FocusScope.of(context).unfocus();
    widget.onSelect(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(28),
              color: cs.surface,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'Search address or landmark',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: _clear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_expanded)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 280),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  color: cs.surface,
                  clipBehavior: Clip.antiAlias,
                  child: _buildResults(cs),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ColorScheme cs) {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No matching locations. Check the spelling and try again.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.place_outlined),
          title: Text(
            r.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            r.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _pick(r),
        );
      },
    );
  }
}
