// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:fcp_client/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FCP Models', () {
    test('WidgetCatalog correctly parsed', () {
      final WidgetCatalog catalog = WidgetCatalog.fromMap(catalogJson);
      expect(catalog.catalogVersion, '1.0.0');
      expect(catalog.items, isA<Map<dynamic, dynamic>>());
      expect(catalog.items.keys, contains('Text'));
    });

    test('WidgetDefinition correctly parsed', () {
      final Map<String, Object?> items =
          catalogJson['items']! as Map<String, Object?>;
      final Map<String, Object?> textItem =
          items['Text']! as Map<String, Object?>;
      final WidgetDefinition itemDef = WidgetDefinition.fromMap(textItem);
      expect(itemDef.properties, isA<ObjectSchema>());
      expect(itemDef.properties.value, contains('data'));
      expect(itemDef.events, isNull);
    });

    test('Layout correctly parsed', () {
      final Layout layout = Layout.fromMap(layoutJson);
      expect(layout.root, 'root_container');
      expect(layout.nodes, isA<List<LayoutNode>>());
      expect(layout.nodes.length, 2);
    });

    test('LayoutNode correctly parsed', () {
      final List<Object?> nodes = layoutJson['nodes']! as List<Object?>;
      final Map<String, Object?> firstNodeMap =
          nodes[0]! as Map<String, Object?>;
      final LayoutNode node = LayoutNode.fromMap(firstNodeMap);
      expect(node.id, 'root_container');
      expect(node.type, 'Container');
      expect(node.properties, isA<Map<dynamic, dynamic>>());
      expect(node.properties!['child'], 'hello_text');
      expect(node.itemTemplate, isNull);
    });

    test('LayoutNode correctly parsed with itemTemplate', () {
      final Layout layout = Layout.fromMap(layoutWithTemplateJson);
      final LayoutNode node = layout.nodes.first;
      expect(node.id, 'my_list_view');
      expect(node.type, 'ListView');
      expect(node.itemTemplate, isNotNull);
      expect(node.itemTemplate, isA<LayoutNode>());
      expect(node.itemTemplate!.id, 'item_template');
      expect(node.itemTemplate!.type, 'Text');
    });

    test('WidgetDefinition correctly parsed with events', () {
      final Map<String, Object?> items =
          catalogJson['items']! as Map<String, Object?>;
      final Map<String, Object?> buttonItem =
          items['Button']! as Map<String, Object?>;
      final WidgetDefinition itemDef = WidgetDefinition.fromMap(buttonItem);
      expect(itemDef.events, isNotNull);
      expect(itemDef.events, isA<ObjectSchema>());
      expect(itemDef.events!.value.containsKey('onPressed'), isTrue);
    });
  });
}

// --- Mock Data ---

final Map<String, Object?> catalogJson =
    json.decode('''
{
  "catalogVersion": "1.0.0",
  "items": {
    "Text": {
      "properties": {
        "data": {
          "type": "string",
          "description": "The text to display."
        }
      },
      "required": ["data"]
    },
    "Container": {
      "properties": {
        "child": {
          "type": "widget"
        },
        "alignment": {
          "type": "string",
          "default": "center",
          "enum": ["center", "topLeft", "bottomRight"]
        }
      }
    },
    "Button": {
      "properties": {},
      "events": {
        "onPressed": {
          "type": "object",
          "properties": {}
        }
      }
    }
  }
}
''')
        as Map<String, Object?>;

final Map<String, Object?> layoutJson =
    json.decode('''
{
  "root": "root_container",
  "nodes": [
    {
      "id": "root_container",
      "type": "Container",
      "properties": {
        "child": "hello_text"
      }
    },
    {
      "id": "hello_text",
      "type": "Text",
      "properties": {
        "data": "Hello"
      }
    }
  ]
}
''')
        as Map<String, Object?>;

final Map<String, Object?> layoutWithTemplateJson =
    json.decode('''
{
    "root": "my_list_view",
    "nodes": [
      {
        "id": "my_list_view",
        "type": "ListView",
        "itemTemplate": {
          "id": "item_template",
          "type": "Text"
        }
      }
    ]
}
''')
        as Map<String, Object?>;
