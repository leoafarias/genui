// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'fcp_state.dart';

/// Processes bindings from a [LayoutNode] to resolve dynamic values from
/// [FcpState].
///
/// This class handles path resolution and transformations (`format`,
/// `condition`, `map`).
class BindingProcessor {
  /// Creates a binding processor that resolves values against the given state.
  BindingProcessor(this.state);

  final FcpState state;

  /// Resolves all bindings for a given layout node against the main state.
  Map<String, Object?> process(LayoutNode node) {
    final WidgetDefinition? itemDefJson = state.catalog.items[node.type];
    if (itemDefJson == null) {
      // It's valid for a widget to not have a definition, in which case
      // it has no properties that can be bound.
      return node.properties ?? const <String, Object?>{};
    }
    final WidgetDefinition itemDef = WidgetDefinition.fromMap(
      itemDefJson as Map<String, Object?>,
    );
    return _processProperties(node.properties, itemDef, null);
  }

  /// Resolves all bindings for a given layout node within a specific data
  /// scope.
  ///
  /// This is used for list item templates, where `item.` paths are resolved
  /// against the `scopedData` object.
  Map<String, Object?> processScoped(
    LayoutNode node,
    Map<String, Object?> scopedData,
  ) {
    final WidgetDefinition? itemDefJson = state.catalog.items[node.type];
    if (itemDefJson == null) {
      // It's valid for a widget to not have a definition, in which case
      // it has no properties that can be bound.
      return node.properties ?? const <String, Object?>{};
    }
    final WidgetDefinition itemDef = WidgetDefinition.fromMap(
      itemDefJson as Map<String, Object?>,
    );
    return _processProperties(node.properties, itemDef, scopedData);
  }

  Map<String, Object?> _processProperties(
    Map<String, Object?>? properties,
    WidgetDefinition itemDef,
    Map<String, Object?>? scopedData,
  ) {
    final Map<String, Object?> resolvedProperties = <String, Object?>{};
    if (properties == null) {
      return resolvedProperties;
    }

    for (final MapEntry<String, Object?> entry in properties.entries) {
      final String propertyName = entry.key;
      final Object? value = entry.value;

      if (value is Map<String, Object?> && value.containsKey(r'$bind')) {
        final Binding binding = Binding.fromMap(value);
        resolvedProperties[propertyName] = _resolveBinding(
          binding,
          propertyName,
          itemDef,
          scopedData,
        );
      } else {
        resolvedProperties[propertyName] = value;
      }
    }

    return resolvedProperties;
  }

  Object? _resolveBinding(
    Binding binding,
    String propertyName,
    WidgetDefinition itemDef,
    Map<String, Object?>? scopedData,
  ) {
    Object? rawValue;
    if (binding.path.startsWith('item.')) {
      // Scoped path, resolve against the item data.
      final String path = binding.path.substring(5);
      rawValue = getValueFromMap(path, scopedData);
    } else {
      // Global path, resolve against the main state.
      rawValue = state.getValue(binding.path);
    }

    if (rawValue == null) {
      debugPrint(
        'FCP Warning: Binding path "${binding.path}" resolved to null.',
      );
      final Schema? propSchema = itemDef.properties.properties?[propertyName];
      if (propSchema != null) {
        return _getDefaultValueForType(propSchema);
      }
      return null;
    }

    return _applyTransformation(rawValue, binding);
  }

  Object? getValueFromMap(String path, Map<String, Object?>? map) {
    if (map == null) return null;
    final List<String> parts = path.split('.');
    Object? currentValue = map;
    for (final String part in parts) {
      if (currentValue is Map<String, Object?>) {
        currentValue = currentValue[part];
      } else {
        return null;
      }
    }
    return currentValue;
  }

  Object? _applyTransformation(Object? value, Binding binding) {
    if (binding.format != null) {
      return binding.format!.replaceAll('{}', value?.toString() ?? '');
    }

    if (binding.condition != null) {
      final Condition condition = binding.condition!;
      if (value == true) {
        return condition.ifValue;
      } else {
        return condition.elseValue;
      }
    }

    if (binding.map != null) {
      final MapTransformer map = binding.map!;
      final String? key = value?.toString();
      return map.mapping[key] ?? map.fallback;
    }

    return value;
  }

  Object? _getDefaultValueForType(Schema schema) {
    if (schema.defaultValue != null) {
      return schema.defaultValue;
    }
    final Object? type = schema.type;
    if (type is String) {
      switch (type) {
        case 'string':
          return '';
        case 'integer':
          return 0;
        case 'number':
          return 0.0;
        case 'boolean':
          return false;
        case 'object':
          return <String, Object?>{};
        case 'array':
          return <Object?>[];
        case 'null':
          return null;
      }
    }
    if (type is List<String>) {
      if (type.isEmpty) {
        return null;
      }
      // Return the default for the first type in the list.
      return _getDefaultValueForType(
        Schema.fromMap(<String, Object?>{'type': type.first}),
      );
    }
    return null;
  }
}
