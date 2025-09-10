// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:dart_schema_builder/dart_schema_builder.dart'
    show ObjectSchema, Schema;

import '../constants.dart';

/// Extension to provide JSON stringification for map-based objects.
extension JsonEncodeMap on Map<String, Object?> {
  /// Converts this map object to a JSON string.
  ///
  /// - [indent]: If non-empty, the JSON output will be pretty-printed with
  ///   the given indent.
  String toJsonString({String indent = ''}) {
    if (indent.isNotEmpty) {
      return JsonEncoder.withIndent(indent).convert(this);
    }
    return const JsonEncoder().convert(this);
  }
}

/// A base extension type for FCP models that are represented as JSON objects.
extension type JsonObjectBase(Map<String, Object?> _json) {
  /// Returns the underlying JSON map.
  Map<String, Object?> toJson() => _json;
}

// -----------------------------------------------------------------------------
// Catalog-related Models
// -----------------------------------------------------------------------------

/// A type-safe wrapper for the `WidgetCatalog` JSON object.
///
/// The catalog is a client-defined document that specifies which widgets,
/// properties, events, and data structures the application is capable of
/// handling. It serves as a strict contract between the client and the server.
extension type WidgetCatalog.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [WidgetCatalog] from a map of [items] and [dataTypes].
  ///
  /// The [catalogVersion] defaults to [fcpVersion].
  factory WidgetCatalog({
    String catalogVersion = fcpVersion,
    required Map<String, Object?> dataTypes,
    required Map<String, WidgetDefinition?> items,
  }) => WidgetCatalog.fromMap(<String, Object?>{
    'catalogVersion': catalogVersion,
    'dataTypes': dataTypes,
    'items': items,
  });

  /// The version of the catalog file itself.
  String get catalogVersion => _json['catalogVersion'] as String;

  /// A map of custom data type names to their JSON Schema definitions.
  Map<String, Object?> get dataTypes =>
      _json['dataTypes'] as Map<String, Object?>;

  /// A map of widget type names to their definitions.
  Map<String, WidgetDefinition?> get items =>
      (_json['items'] as Map<dynamic, dynamic>)
          .cast<String, WidgetDefinition?>();
}

/// A type-safe wrapper for a `WidgetDefinition` JSON object.
///
/// This object describes a single renderable widget type, including its
/// supported properties and the events it can emit.
extension type WidgetDefinition.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [WidgetDefinition] from a [properties] schema and an
  /// optional [events] schema.
  factory WidgetDefinition({
    required ObjectSchema properties,
    ObjectSchema? events,
  }) => WidgetDefinition.fromMap(<String, Object?>{
    'properties': properties.value,
    if (events != null) 'events': events.value,
  });

  /// A JSON Schema object that defines the supported attributes for the widget.
  ObjectSchema get properties {
    final Map<String, Object?>? props =
        _json['properties'] as Map<String, Object?>?;
    if (props == null) {
      return ObjectSchema(properties: <String, Schema>{});
    }
    return ObjectSchema.fromMap(props);
  }

  /// A map of event names to their JSON Schema definitions.
  ObjectSchema? get events {
    final Map<String, Object?>? events =
        _json['events'] as Map<String, Object?>?;
    return events == null ? null : ObjectSchema.fromMap(events);
  }
}

// -----------------------------------------------------------------------------
// UI Packet & Layout Models
// -----------------------------------------------------------------------------

/// A type-safe wrapper for a `Layout` JSON object.
///
/// The layout defines the UI structure using a flat adjacency list model,
/// where parent-child relationships are established through ID references.
extension type Layout.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [Layout] from a [root] node ID and a list of [nodes].
  factory Layout({required String root, required List<LayoutNode> nodes}) =>
      Layout.fromMap(<String, Object?>{
        'root': root,
        'nodes': nodes.map((LayoutNode e) => e.toJson()).toList(),
      });

  /// The ID of the root layout node.
  String get root => _json['root'] as String;

  /// A flat list of all the layout nodes in the UI.
  List<LayoutNode> get nodes {
    final List<Object?> nodeList =
        _json['nodes'] as List<Object?>? ?? <Object?>[];
    return nodeList
        .cast<Map<String, Object?>>()
        .map(LayoutNode.fromMap)
        .toList();
  }
}

/// A type-safe wrapper for a `LayoutNode` JSON object.
///
/// A layout node represents a single widget instance in the layout,
/// including its type, properties, and data bindings.
extension type LayoutNode.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [LayoutNode] from an [id] and [type].
  ///
  /// The [properties] and [itemTemplate] are optional.
  factory LayoutNode({
    required String id,
    required String type,
    Map<String, Object?>? properties,
    LayoutNode? itemTemplate,
  }) => LayoutNode.fromMap(<String, Object?>{
    'id': id,
    'type': type,
    if (properties != null) 'properties': properties,
    if (itemTemplate != null) 'itemTemplate': itemTemplate.toJson(),
  });

  /// The unique identifier for this widget instance.
  String get id => _json['id'] as String;

  /// The type of the widget, which must match a key in the [WidgetCatalog].
  String get type => _json['type'] as String;

  /// Static properties for this widget. May also contain inline bindings.
  Map<String, Object?>? get properties =>
      _json['properties'] as Map<String, Object?>?;

  /// A template node for list builder widgets.
  LayoutNode? get itemTemplate {
    final Map<String, Object?>? templateJson =
        _json['itemTemplate'] as Map<String, Object?>?;
    return templateJson != null ? LayoutNode.fromMap(templateJson) : null;
  }
}

// -----------------------------------------------------------------------------
// State & Binding Models
// -----------------------------------------------------------------------------

/// A type-safe wrapper for a `Binding` JSON object.
///
/// A binding forges the connection between a widget property in the
/// layout and a value in the state object, with optional client-side
/// transformations.
extension type Binding.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [Binding] from a `\$bind` path to a value in the state.
  ///
  /// The [format], [condition], and [map] parameters are optional
  /// transformers.
  factory Binding({
    required String path,
    String? format,
    Condition? condition,
    MapTransformer? map,
  }) => Binding.fromMap(<String, Object?>{
    r'$bind': path,
    if (format != null) 'format': format,
    if (condition != null) 'condition': condition.toJson(),
    if (map != null) 'map': map.toJson(),
  });

  /// The path to the data in the state object.
  String get path => _json[r'$bind'] as String;

  /// A string with a `{}` placeholder, which will be replaced by the value.
  String? get format => _json['format'] as String?;

  /// A conditional transformer.
  Condition? get condition {
    final Map<String, Object?>? conditionJson =
        _json['condition'] as Map<String, Object?>?;
    return conditionJson != null ? Condition.fromMap(conditionJson) : null;
  }

  /// A map transformer.
  MapTransformer? get map {
    final Map<String, Object?>? mapJson = _json['map'] as Map<String, Object?>?;
    return mapJson != null ? MapTransformer.fromMap(mapJson) : null;
  }
}

/// A type-safe wrapper for a `Condition` transformer JSON object.
///
/// This transformer evaluates a boolean value from the state and returns one
/// of two specified values.
extension type Condition.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [Condition] from an optional [ifValue] and [elseValue].
  factory Condition({Object? ifValue, Object? elseValue}) =>
      Condition.fromMap(<String, Object?>{
        if (ifValue != null) 'ifValue': ifValue,
        if (elseValue != null) 'elseValue': elseValue,
      });

  /// The value to use if the state value is `true`.
  Object? get ifValue => _json['ifValue'];

  /// The value to use if the state value is `false`.
  Object? get elseValue => _json['elseValue'];
}

/// A type-safe wrapper for a `Map` transformer JSON object.
///
/// This transformer maps a value from the state to another value, with an
/// optional fallback.
extension type MapTransformer.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [MapTransformer] from a [mapping] and an optional
  /// [fallback].
  factory MapTransformer({
    required Map<String, Object?> mapping,
    Object? fallback,
  }) => MapTransformer.fromMap(<String, Object?>{
    'mapping': mapping,
    if (fallback != null) 'fallback': fallback,
  });

  /// A map of possible state values to their desired output.
  Map<String, Object?> get mapping => _json['mapping'] as Map<String, Object?>;

  /// A value to use if the state value is not in the map.
  Object? get fallback => _json['fallback'];
}
