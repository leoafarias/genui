// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:genai_primitives/genai_primitives.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../model/catalog.dart';
import '../model/catalog_item.dart';
import '../primitives/simple_items.dart';

/// Resolves catalog context for incremental catalog prompt mode.
///
/// Provides pure functions over an in-process [Catalog] so integrations can
/// expose [loadCatalogItemsTool] to an LLM and resolve tool calls via
/// [executeTool] or [loadItems].
///
/// ```dart
/// final tool = CatalogContext.loadCatalogItemsTool;
/// // Register `tool.name`, `tool.description`, and `tool.inputSchema` with
/// // your LLM client, and forward tool invocations to:
/// final responseJson = CatalogContext.executeTool(catalog, toolArgs);
/// ```
abstract final class CatalogContext {
  CatalogContext._();

  /// The canonical `loadCatalogItems` tool definition for incremental mode.
  ///
  /// Register this tool's `name`, `description`, and `inputSchema` with the
  /// LLM provider's tool framework, and forward the parsed input map to
  /// [executeTool] (or item names to [loadItems]).
  static final ToolDefinition<Map<String, Object?>> loadCatalogItemsTool =
      ToolDefinition(
        name: 'loadCatalogItems',
        description:
            'Loads the A2UI schemas and examples for the named catalog items. '
            'Pass all the components you need for this turn (excluding any '
            'already loaded via loadCatalogItems in an earlier turn) in one '
            'call, using exact item names from the catalog manifest. Returns '
            'each component\'s schema and examples so you can emit valid '
            'updateComponents.',
        inputSchema: S.object(
          properties: {
            'items': S.list(
              items: S.string(
                description: 'A catalog item name from the manifest.',
              ),
              description:
                  'The catalog item names to load: all the components '
                  'you need for this turn that were not already loaded via '
                  'loadCatalogItems in an earlier turn.',
            ),
          },
          required: ['items'],
        ),
      );

  /// Builds a compact JSON manifest of [catalog].
  ///
  /// The manifest contains only `name` and `description` entries for each
  /// item in [catalog] (plus `catalogId` when present), omitting full schemas
  /// and examples. Items are deduplicated by canonical name in first-seen
  /// order.
  static JsonMap manifest(Catalog catalog) {
    final seen = <String>{};
    final items = <JsonMap>[];
    for (final CatalogItem item in catalog.items) {
      if (!seen.add(item.name)) continue;
      items.add(<String, Object?>{
        'name': item.name,
        'description': item.description,
      });
    }
    return {
      if (catalog.catalogId != null) 'catalogId': catalog.catalogId,
      'items': items,
    };
  }

  /// Executes a [loadCatalogItemsTool] invocation against [catalog] using raw
  /// tool [args].
  ///
  /// Extracts the `items` list from [args] and delegates to [loadItems].
  ///
  /// Throws an [ArgumentError] if `args['items']` is missing or contains
  /// non-string entries, or a [CatalogItemNotFoundException] if any requested
  /// item name does not exist in [catalog].
  static JsonMap executeTool(Catalog catalog, Map<String, Object?> args) {
    final Object? rawItems = args['items'];
    if (rawItems is! List<Object?>) {
      throw ArgumentError.value(
        args,
        'args',
        'Expected "items" to be a List of component names.',
      );
    }
    final names = <String>[
      for (final Object? entry in rawItems)
        if (entry is String)
          entry
        else
          throw ArgumentError.value(
            entry,
            'items',
            'Expected every entry in "items" to be a String.',
          ),
    ];
    return loadItems(catalog, names);
  }

  /// Loads schemas and examples for the requested item [names] from [catalog].
  ///
  /// Item lookup is exact-match first with a case-insensitive fallback, and
  /// results are deduplicated by canonical item name in first-seen order.
  ///
  /// Throws a [CatalogItemNotFoundException] if any requested item name is not
  /// found in [catalog], or a [FormatException] if a loaded item's example
  /// JSON is malformed.
  static JsonMap loadItems(Catalog catalog, Iterable<String> names) {
    final Map<String, CatalogItem> byName = {
      for (final item in catalog.items) item.name: item,
    };
    final Map<String, CatalogItem> byNameLower = {
      for (final item in catalog.items) item.name.toLowerCase(): item,
    };

    final seen = <String>{};
    final details = <JsonMap>[];
    for (final name in names) {
      final CatalogItem? item = byName[name] ?? byNameLower[name.toLowerCase()];
      if (item == null) {
        throw CatalogItemNotFoundException(name, catalogId: catalog.catalogId);
      }
      if (!seen.add(item.name)) continue;
      details.add({
        'name': item.name,
        'description': item.description,
        'schema': item.envelopeSchema,
        'examples': item.decodedExamples,
      });
    }

    return {
      if (catalog.catalogId != null) 'catalogId': catalog.catalogId,
      'items': details,
    };
  }
}
