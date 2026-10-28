// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  final catalog = Catalog([
    BasicCatalogItems.card,
    BasicCatalogItems.text,
    BasicCatalogItems.button,
  ], catalogId: 'test_catalog');

  // A custom item with its own schema description, used to verify the manifest
  // derives its description from the schema (single source of truth).
  final fancyItem = CatalogItem(
    name: 'Fancy',
    dataSchema: S.object(
      description: 'A fancy component for decorative content.',
      properties: {'label': S.string()},
      required: ['label'],
    ),
    widgetBuilder: (_) => const SizedBox.shrink(),
  );
  final metaCatalog = Catalog([fancyItem], catalogId: 'meta_catalog');

  List<JsonMap> itemsOf(JsonMap payload) =>
      (payload['items']! as List<Object?>).cast<JsonMap>();

  group('CatalogContext.manifest', () {
    test('includes catalog item names and descriptions', () {
      final JsonMap manifest = CatalogContext.manifest(catalog);
      final List<JsonMap> items = itemsOf(manifest);

      expect(
        items.map((JsonMap e) => e['name']),
        containsAll(<String>['Card', 'Text', 'Button']),
      );

      final JsonMap card = items.firstWhere((JsonMap e) => e['name'] == 'Card');
      // Don't pin the exact wording (it lives in BasicCatalogItems and may
      // change). The "derives from schema description" test below pins the
      // wiring with a controlled item.
      expect(card['description'], isA<String>());
      expect(card['description']! as String, isNotEmpty);
      expect(manifest['catalogId'], 'test_catalog');
    });

    test('derives the description from the schema description', () {
      final JsonMap manifest = CatalogContext.manifest(metaCatalog);
      final JsonMap item = itemsOf(manifest).single;

      expect(item['description'], 'A fancy component for decorative content.');
    });

    test('manifest items only carry name and description', () {
      final JsonMap manifest = CatalogContext.manifest(catalog);

      for (final JsonMap item in itemsOf(manifest)) {
        final Iterable<String> keys = item.keys;
        expect(keys, containsAll(<String>['name', 'description']));
        expect(keys, hasLength(2));
      }
    });

    test('omits catalogId when catalogId is null', () {
      final anonymousCatalog = Catalog(<CatalogItem>[BasicCatalogItems.text]);
      final JsonMap manifest = CatalogContext.manifest(anonymousCatalog);

      expect(manifest.containsKey('catalogId'), isFalse);
      expect(manifest['catalogId'], isNull);
      expect(itemsOf(manifest), hasLength(1));
      expect(itemsOf(manifest).single['name'], 'Text');
    });

    test('derives fallback description when schema has no description', () {
      final noDescItem = CatalogItem(
        name: 'Plain',
        dataSchema: S.object(properties: <String, Schema>{'value': S.string()}),
        widgetBuilder: (_) => const SizedBox.shrink(),
      );
      final catalog = Catalog(<CatalogItem>[
        noDescItem,
      ], catalogId: 'plain_cat');
      final JsonMap manifest = CatalogContext.manifest(catalog);
      final JsonMap item = itemsOf(manifest).single;

      expect(item['description'], 'A2UI component named Plain.');
    });

    test(
      'derives fallback description when schema description is whitespace',
      () {
        final whitespaceDescItem = CatalogItem(
          name: 'Whitespace',
          dataSchema: S.object(
            description: '   \t\n  ',
            properties: <String, Schema>{'value': S.string()},
          ),
          widgetBuilder: (_) => const SizedBox.shrink(),
        );
        final catalog = Catalog(<CatalogItem>[
          whitespaceDescItem,
        ], catalogId: 'ws_cat');
        final JsonMap manifest = CatalogContext.manifest(catalog);
        final JsonMap item = itemsOf(manifest).single;

        expect(item['description'], 'A2UI component named Whitespace.');
      },
    );

    test('trims whitespace surrounding schema description', () {
      final paddedItem = CatalogItem(
        name: 'Padded',
        dataSchema: S.object(
          description: '  Padded description text.  \n',
          properties: <String, Schema>{'value': S.string()},
        ),
        widgetBuilder: (_) => const SizedBox.shrink(),
      );
      final catalog = Catalog(<CatalogItem>[
        paddedItem,
      ], catalogId: 'padded_cat');
      final JsonMap manifest = CatalogContext.manifest(catalog);
      final JsonMap item = itemsOf(manifest).single;

      expect(item['description'], 'Padded description text.');
    });

    test('deduplicates catalog items by name in first-seen order', () {
      final duplicateCatalog = Catalog(<CatalogItem>[
        BasicCatalogItems.card,
        BasicCatalogItems.text,
        BasicCatalogItems.card,
        BasicCatalogItems.button,
        BasicCatalogItems.text,
      ], catalogId: 'duplicate_catalog');

      final JsonMap manifest = CatalogContext.manifest(duplicateCatalog);
      final List<JsonMap> items = itemsOf(manifest);

      expect(items.map((JsonMap e) => e['name']), <String>[
        'Card',
        'Text',
        'Button',
      ]);
      expect(items, hasLength(3));
    });

    test(
      'preserves the first encountered item description when duplicates exist',
      () {
        final item1 = CatalogItem(
          name: 'DuplicatedWidget',
          dataSchema: S.object(description: 'First description.'),
          widgetBuilder: (_) => const SizedBox.shrink(),
        );
        final item2 = CatalogItem(
          name: 'DuplicatedWidget',
          dataSchema: S.object(description: 'Second description.'),
          widgetBuilder: (_) => const SizedBox.shrink(),
        );
        final duplicateCatalog = Catalog(<CatalogItem>[
          item1,
          item2,
        ], catalogId: 'dup_desc_catalog');

        final JsonMap manifest = CatalogContext.manifest(duplicateCatalog);
        final List<JsonMap> items = itemsOf(manifest);

        expect(items, hasLength(1));
        expect(items.single['name'], 'DuplicatedWidget');
        expect(items.single['description'], 'First description.');
      },
    );
  });

  group('CatalogContext.loadItems', () {
    test('returns details for the requested items', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
        'Text',
      ]);

      expect(itemsOf(result).map((JsonMap e) => e['name']), <String>[
        'Card',
        'Text',
      ]);
      expect(result['catalogId'], 'test_catalog');
    });

    test('omits catalogId when catalogId is null', () {
      final anonymousCatalog = Catalog(<CatalogItem>[BasicCatalogItems.text]);
      final JsonMap result = CatalogContext.loadItems(
        anonymousCatalog,
        <String>['Text'],
      );

      expect(result.containsKey('catalogId'), isFalse);
      expect(result['catalogId'], isNull);
      expect(itemsOf(result).map((JsonMap e) => e['name']), <String>['Text']);
    });

    test(
      'throws for unknown catalog item with null catalogId when anonymous',
      () {
        final anonymousCatalog = Catalog(<CatalogItem>[BasicCatalogItems.text]);

        expect(
          () => CatalogContext.loadItems(anonymousCatalog, <String>[
            'NotAComponent',
          ]),
          throwsA(
            isA<CatalogItemNotFoundException>()
                .having((e) => e.widgetType, 'widgetType', 'NotAComponent')
                .having((e) => e.catalogId, 'catalogId', isNull),
          ),
        );
      },
    );

    test('loaded schema includes id, component, and accessibility', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final schema = itemsOf(result).single['schema']! as JsonMap;
      final properties = schema['properties']! as Map<String, Object?>;

      expect(
        properties.keys,
        containsAll(<String>['id', 'component', 'accessibility', 'child']),
      );
    });

    test('loaded schema marks id and component as required', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final schema = itemsOf(result).single['schema']! as JsonMap;
      final required = schema['required']! as List<Object?>;

      expect(required, containsAll(<String>['id', 'component']));
      expect(required, isNot(contains('accessibility')));
    });

    test('loaded Card schema keeps child as required', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final schema = itemsOf(result).single['schema']! as JsonMap;
      final required = schema['required']! as List<Object?>;

      expect(required, contains('child'));
    });

    test('loaded schema rejects additional properties', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final schema = itemsOf(result).single['schema']! as JsonMap;

      expect(schema['additionalProperties'], isFalse);
    });

    test('rewrites common-types refs in loaded schemas', () {
      final referencedItem = CatalogItem(
        name: 'Referenced',
        dataSchema: ObjectSchema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'action': <String, Object?>{
              r'$ref': '$commonTypesSchemaId#/\$defs/Action',
            },
          },
        }),
        widgetBuilder: (_) => const SizedBox.shrink(),
      );
      final referencedCatalog = Catalog(<CatalogItem>[
        referencedItem,
      ], catalogId: 'referenced_catalog');

      final JsonMap result = CatalogContext.loadItems(
        referencedCatalog,
        <String>['Referenced'],
      );
      final encodedSchema = itemsOf(result).single['schema'].toString();

      expect(encodedSchema, contains(r'common_types.json#/$defs/Action'));
      expect(encodedSchema, isNot(contains('https://a2ui.org')));
    });

    test('parses example JSON when valid', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final examples = itemsOf(result).single['examples']! as List<Object?>;

      expect(examples, hasLength(1));
      expect(examples.first, isA<List<Object?>>());
    });

    test('identifies the item and example when example JSON is invalid', () {
      final invalidExampleItem = CatalogItem(
        name: 'BrokenCard',
        dataSchema: S.object(),
        widgetBuilder: (_) => const SizedBox.shrink(),
        exampleData: <ExampleBuilderCallback>[
          () => '[]',
          () => '{invalid json',
        ],
      );
      final invalidExampleCatalog = Catalog(<CatalogItem>[
        invalidExampleItem,
      ], catalogId: 'invalid_example_catalog');

      expect(
        () => CatalogContext.loadItems(invalidExampleCatalog, <String>[
          'BrokenCard',
        ]),
        throwsA(
          isA<FormatException>()
              .having(
                (FormatException error) => error.message,
                'message',
                allOf(contains('BrokenCard'), contains('example 1')),
              )
              .having(
                (FormatException error) => error.source,
                'source',
                '{invalid json',
              )
              .having(
                (FormatException error) => error.offset,
                'offset',
                isNotNull,
              ),
        ),
      );
    });

    test('preserves request order and removes duplicates', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Button',
        'Card',
        'Button',
      ]);

      expect(itemsOf(result).map((JsonMap e) => e['name']), <String>[
        'Button',
        'Card',
      ]);
    });

    test(
      'supports case-insensitive lookup and deduplicates canonical names',
      () {
        final JsonMap result = CatalogContext.loadItems(catalog, <String>[
          'card',
          'TEXT',
          'Card',
        ]);

        expect(itemsOf(result).map((JsonMap e) => e['name']), <String>[
          'Card',
          'Text',
        ]);
      },
    );

    test('throws for unknown catalog item', () {
      expect(
        () => CatalogContext.loadItems(catalog, <String>['NotAComponent']),
        throwsA(
          isA<CatalogItemNotFoundException>()
              .having((e) => e.widgetType, 'widgetType', 'NotAComponent')
              .having((e) => e.catalogId, 'catalogId', 'test_catalog'),
        ),
      );
    });

    test('accepts an empty request', () {
      final JsonMap result = CatalogContext.loadItems(
        catalog,
        const <String>[],
      );

      expect(itemsOf(result), isEmpty);
    });

    test('details carry only name, description, schema, and examples', () {
      final JsonMap result = CatalogContext.loadItems(catalog, <String>[
        'Card',
      ]);
      final Iterable<String> keys = itemsOf(result).single.keys;

      expect(
        keys,
        containsAll(<String>['name', 'description', 'schema', 'examples']),
      );
      expect(keys, hasLength(4));
    });

    test(
      'loads all BasicCatalogItems and validates examples against schemas',
      () {
        final Catalog basicCatalog = BasicCatalogItems.asCatalog();
        final List<String> allNames = basicCatalog.items
            .map((CatalogItem item) => item.name)
            .toList();
        final JsonMap result = CatalogContext.loadItems(basicCatalog, allNames);
        final List<JsonMap> loadedItems = itemsOf(result);

        expect(loadedItems, hasLength(allNames.length));
        final byName = <String, JsonMap>{
          for (final JsonMap item in loadedItems) item['name']! as String: item,
        };

        for (final item in loadedItems) {
          final itemName = item['name']! as String;
          final examples = item['examples']! as List<Object?>;
          for (final example in examples) {
            expect(example, isA<List<Object?>>());
            for (final rawComponent in example! as List<Object?>) {
              final component = rawComponent! as Map<String, Object?>;
              final componentName = component['component'] as String;
              final JsonMap? target = byName[componentName];
              expect(
                target,
                isNotNull,
                reason:
                    'Example in $itemName references unknown component '
                    '$componentName',
              );
              final targetSchema = target!['schema']! as JsonMap;
              final properties =
                  targetSchema['properties']! as Map<String, Object?>;
              final required = targetSchema['required']! as List<Object?>;
              expect(
                component.keys,
                containsAll(required),
                reason:
                    'Example component $componentName in $itemName is '
                    'missing required properties',
              );
              for (final String key in component.keys) {
                expect(
                  properties.keys,
                  contains(key),
                  reason:
                      'Example component $componentName in $itemName uses '
                      'undeclared property "$key"',
                );
              }
            }
          }
        }
      },
    );
  });

  group('CatalogContext.executeTool', () {
    test('executes tool call from raw args map', () {
      final JsonMap result = CatalogContext.executeTool(
        catalog,
        <String, Object?>{
          'items': <Object?>['Card', 'button'],
        },
      );

      expect(itemsOf(result).map((JsonMap e) => e['name']), <String>[
        'Card',
        'Button',
      ]);
    });

    test('accepts empty items list and returns empty items map', () {
      final JsonMap result = CatalogContext.executeTool(
        catalog,
        <String, Object?>{'items': <Object?>[]},
      );

      expect(itemsOf(result), isEmpty);
      expect(result['catalogId'], 'test_catalog');
    });

    test('ignores extraneous arguments in args map', () {
      final JsonMap result = CatalogContext.executeTool(
        catalog,
        <String, Object?>{
          'items': <Object?>['Card'],
          'extraArgument': 'should_be_ignored',
          'explanation': 'Fetching card for UI rendering',
          'turn': 3,
        },
      );

      expect(itemsOf(result).map((JsonMap e) => e['name']), <String>['Card']);
      expect(result['catalogId'], 'test_catalog');
    });

    test('accepts empty items list with extraneous arguments', () {
      final JsonMap result = CatalogContext.executeTool(
        catalog,
        <String, Object?>{'items': <Object?>[], 'extraArg': 42},
      );

      expect(itemsOf(result), isEmpty);
      expect(result['catalogId'], 'test_catalog');
    });

    test('throws ArgumentError when items key is missing or not a list', () {
      expect(
        () => CatalogContext.executeTool(catalog, const <String, Object?>{}),
        throwsArgumentError,
      );
      expect(
        () => CatalogContext.executeTool(catalog, const <String, Object?>{
          'items': 'Card',
        }),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when items contains a non-string entry', () {
      expect(
        () => CatalogContext.executeTool(catalog, const <String, Object?>{
          'items': <Object?>['Card', 42],
        }),
        throwsArgumentError,
      );
    });
  });

  group('CatalogContext.loadCatalogItemsTool', () {
    test('exposes a canonical ToolDefinition for incremental mode', () {
      final ToolDefinition<Map<String, Object?>> tool =
          CatalogContext.loadCatalogItemsTool;

      expect(tool.name, 'loadCatalogItems');
      expect(tool.description, isNotEmpty);
      expect(
        tool.description,
        contains('exact item names from the catalog manifest'),
      );
      expect(tool.description, isNot(contains('"Card"')));

      final Map<String, Object?> schema = tool.inputSchema.value;
      expect(schema['type'], 'object');
      final properties = schema['properties'] as Map<String, Object?>;
      expect(properties.keys, contains('items'));
      expect(schema['required'], contains('items'));
    });
  });
}
