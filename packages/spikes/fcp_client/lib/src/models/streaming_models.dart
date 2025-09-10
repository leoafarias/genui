// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'models.dart';

/// A base type for all incoming stream messages.
sealed class StreamMessage {
  /// Creates a [StreamMessage] from a map.
  factory StreamMessage.fromMap(Map<String, Object?> map) {
    final String? type = map['messageType'] as String?;
    switch (type) {
      case 'StreamHeader':
        return StreamHeader.fromMap(map);
      case 'Layout':
        return LayoutMessage.fromMap(map);
      case 'LayoutRoot':
        return LayoutRoot.fromMap(map);
      case 'StateUpdate':
        return StateUpdateMessage.fromMap(map);
      case 'UnknownCatalogError':
        return UnknownCatalogError.fromMap(map);
      default:
        throw FormatException('Unknown stream message type: $type');
    }
  }
}

/// A type-safe wrapper for a `StreamHeader` JSON object.
class StreamHeader implements StreamMessage {
  /// Creates a new [StreamHeader] from a map.
  StreamHeader.fromMap(Map<String, Object?> json)
    : formatVersion = json['formatVersion'] as String,
      initialState =
          json['initialState'] as Map<String, Object?>? ?? <String, Object?>{};

  /// The version of the GSP specification.
  final String formatVersion;

  /// The initial state data for the UI.
  final Map<String, Object?> initialState;
}

/// A type-safe wrapper for a `Layout` message JSON object.
class LayoutMessage implements StreamMessage {
  /// Creates a new [LayoutMessage] from a map.
  LayoutMessage.fromMap(Map<String, Object?> json)
    : nodes = (json['nodes'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(LayoutNode.fromMap)
          .toList();

  /// A list of layout nodes.
  final List<LayoutNode> nodes;
}

/// A type-safe wrapper for a `LayoutRoot` message JSON object.
class LayoutRoot implements StreamMessage {
  /// Creates a new [LayoutRoot] from a map.
  LayoutRoot.fromMap(Map<String, Object?> json)
    : rootId = json['rootId'] as String;

  /// The ID of the root layout node.
  final String rootId;
}

/// A type-safe wrapper for a `StateUpdate` message JSON object.
class StateUpdateMessage implements StreamMessage {
  /// Creates a new [StateUpdateMessage] from a map.
  StateUpdateMessage.fromMap(Map<String, Object?> json)
    : state = json['state'] as Map<String, Object?>;

  /// A partial state object to be merged with the current state.
  final Map<String, Object?> state;
}

/// A type-safe wrapper for an `UnknownCatalogError` message JSON object.
class UnknownCatalogError implements StreamMessage {
  /// Creates a new [UnknownCatalogError] from a map.
  UnknownCatalogError.fromMap(Map<String, Object?> json)
    : error = json['error'] as String,
      message = json['message'] as String;

  /// The error type.
  final String error;

  /// A human-readable error message.
  final String message;
}

/// A type-safe wrapper for a `ClientRequest` JSON object.
extension type ClientRequest.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [ClientRequest].
  factory ClientRequest({
    CatalogReference? catalogReference,
    WidgetCatalog? catalog,
    Event? event,
    Layout? layout,
    Map<String, Object?>? state,
  }) => ClientRequest.fromMap(<String, Object?>{
    'messageType': 'ClientRequest',
    if (catalogReference != null) 'catalogReference': catalogReference.toJson(),
    if (catalog != null) 'catalog': catalog.toJson(),
    if (event != null) 'event': event.toJson(),
    if (layout != null) 'layout': layout.toJson(),
    if (state != null) 'state': state,
  });

  /// A reference to a predefined base catalog.
  CatalogReference? get catalogReference => _json['catalogReference'] != null
      ? CatalogReference.fromMap(
          _json['catalogReference'] as Map<String, Object?>,
        )
      : null;

  /// The widget catalog.
  WidgetCatalog? get catalog => _json['catalog'] != null
      ? WidgetCatalog.fromMap(_json['catalog'] as Map<String, Object?>)
      : null;

  /// The event that triggered this request.
  Event? get event => _json['event'] != null
      ? Event.fromMap(_json['event'] as Map<String, Object?>)
      : null;

  /// The layout of the UI when the event was triggered.
  Layout? get layout => _json['layout'] != null
      ? Layout.fromMap(_json['layout'] as Map<String, Object?>)
      : null;

  /// The state of the UI when the event was triggered.
  Map<String, Object?>? get state => _json['state'] as Map<String, Object?>?;
}

/// A type-safe wrapper for a `CatalogReference` JSON object.
extension type CatalogReference.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [CatalogReference].
  factory CatalogReference({required String name, required String version}) =>
      CatalogReference.fromMap(<String, Object?>{
        'name': name,
        'version': version,
      });

  /// The name of the catalog.
  String get name => _json['name'] as String;

  /// The version of the catalog.
  String get version => _json['version'] as String;
}

/// A type-safe wrapper for an `Event` JSON object.
extension type Event.fromMap(Map<String, Object?> _json)
    implements JsonObjectBase {
  /// Creates a new [Event].
  factory Event({
    required String sourceNodeId,
    required String eventName,
    required DateTime timestamp,
    Map<String, Object?>? arguments,
  }) => Event.fromMap(<String, Object?>{
    'sourceNodeId': sourceNodeId,
    'eventName': eventName,
    'timestamp': timestamp.toIso8601String(),
    if (arguments != null) 'arguments': arguments,
  });

  /// The ID of the node that generated the event.
  String get sourceNodeId => _json['sourceNodeId'] as String;

  /// The name of the event.
  String get eventName => _json['eventName'] as String;

  /// The time the event occurred.
  DateTime get timestamp => DateTime.parse(_json['timestamp'] as String);

  /// Event-specific arguments.
  Map<String, Object?>? get arguments =>
      _json['arguments'] as Map<String, Object?>?;
}
