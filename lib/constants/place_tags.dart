/// Default tag vocabulary for places.
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

/// A small set of built-in tags always offered when tagging a place. User
/// tags found on existing places are merged with these at the point of use.

const List<String> defaultPlaceTags = [
  'Home',
  'Work',
  'Favourite',
  'Restaurant',
  'Cafe',
  'Shop',
  'Park',
  'Landmark',
  'Accommodation',
  'To Visit',
];
