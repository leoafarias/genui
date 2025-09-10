// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fcp_client/src/core/binding_processor.dart';
import 'package:fcp_client/src/core/data_type_validator.dart';
import 'package:fcp_client/src/core/fcp_state.dart';
import 'package:fcp_client/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BindingProcessor', () {
    late FcpState state;
    late BindingProcessor processor;

    setUp(() {
      state = FcpState(
        <String, Object?>{
          'user': <String, Object>{'name': 'Alice', 'isPremium': true},
          'status': 'active',
          'count': 42,
        },
        validator: DataTypeValidator(),
        catalog: WidgetCatalog.fromMap(<String, Object?>{
          'catalogVersion': '1.0.0',
          'dataTypes': <String, Object?>{},
          'items': <String, Map<String, Map<String, Map<String, String>>>>{
            'Text': <String, Map<String, Map<String, String>>>{
              'properties': <String, Map<String, String>>{
                'text': <String, String>{'type': 'string'},
                'value': <String, String>{'type': 'int'},
                'age': <String, String>{'type': 'int'},
              },
            },
          },
        }),
      );
      processor = BindingProcessor(state);
    });

    test('resolves simple path binding', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{r'$bind': 'user.name'},
          },
        }),
      );
      expect(result['text'], 'Alice');
    });

    test('handles format transformer', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'user.name',
              'format': 'Welcome, {}!',
            },
          },
        }),
      );
      expect(result['text'], 'Welcome, Alice!');
    });

    test('handles condition transformer (true case)', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'user.isPremium',
              'condition': <String, String>{
                'ifValue': 'Premium User',
                'elseValue': 'Standard User',
              },
            },
          },
        }),
      );
      expect(result['text'], 'Premium User');
    });

    test('handles condition transformer (false case)', () {
      state.state = <String, Object?>{
        'user': <String, bool>{'isPremium': false},
      };
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'user.isPremium',
              'condition': <String, String>{
                'ifValue': 'Premium User',
                'elseValue': 'Standard User',
              },
            },
          },
        }),
      );
      expect(result['text'], 'Standard User');
    });

    test('handles map transformer (found case)', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'status',
              'map': <String, Object>{
                'mapping': <String, String>{
                  'active': 'Online',
                  'inactive': 'Offline',
                },
                'fallback': 'Unknown',
              },
            },
          },
        }),
      );
      expect(result['text'], 'Online');
    });

    test('handles map transformer (fallback case)', () {
      state.state = <String, Object?>{'status': 'away'};
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'status',
              'map': <String, Object>{
                'mapping': <String, String>{
                  'active': 'Online',
                  'inactive': 'Offline',
                },
                'fallback': 'Unknown',
              },
            },
          },
        }),
      );
      expect(result['text'], 'Unknown');
    });

    test('handles map transformer with no fallback (miss case)', () {
      state.state = <String, Object?>{'status': 'away'};
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'text': <String, Object?>{
              r'$bind': 'status',
              'map': <String, Map<String, String>>{
                'mapping': <String, String>{
                  'active': 'Online',
                  'inactive': 'Offline',
                },
              },
            },
          },
        }),
      );
      expect(result['text'], isNull);
    });

    test('returns raw value when no transformer is present', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{
            'value': <String, Object?>{r'$bind': 'count'},
          },
        }),
      );
      expect(result['value'], 42);
    });

    test('returns empty map for empty properties', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{
          'id': 'w1',
          'type': 'Text',
          'properties': <String, Object?>{},
        }),
      );
      expect(result, isEmpty);
    });

    test('returns empty map for null properties', () {
      final Map<String, Object?> result = processor.process(
        LayoutNode.fromMap(<String, Object?>{'id': 'w1', 'type': 'Text'}),
      );
      expect(result, isEmpty);
    });

    test(
      'returns default value for a path that does not exist in the state',
      () {
        final Map<String, Object?> result = processor.process(
          LayoutNode.fromMap(<String, Object?>{
            'id': 'w1',
            'type': 'Text',
            'properties': <String, Object?>{
              'age': <String, Object?>{r'$bind': 'user.age'},
            },
          }),
        );
        expect(result['age'], isNull);
      },
    );

    group('Scoped Bindings', () {
      final Map<String, Object> scopedData = <String, Object>{
        'title': 'Scoped Title',
        'value': 100,
      };

      test('resolves item path from scoped data', () {
        final Map<String, Object?> result = processor.processScoped(
          LayoutNode.fromMap(<String, Object?>{
            'id': 'w1',
            'type': 'Text',
            'properties': <String, Object?>{
              'text': <String, Object?>{r'$bind': 'item.title'},
            },
          }),
          scopedData,
        );
        expect(result['text'], 'Scoped Title');
      });

      test('resolves global path even when scoped data is present', () {
        final Map<String, Object?> result = processor.processScoped(
          LayoutNode.fromMap(<String, Object?>{
            'id': 'w1',
            'type': 'Text',
            'properties': <String, Object?>{
              'text': <String, Object?>{r'$bind': 'user.name'},
            },
          }),
          scopedData,
        );
        expect(result['text'], 'Alice');
      });

      test('applies transformer to scoped data', () {
        final Map<String, Object?> result = processor.processScoped(
          LayoutNode.fromMap(<String, Object?>{
            'id': 'w1',
            'type': 'Text',
            'properties': <String, Object?>{
              'text': <String, Object?>{
                r'$bind': 'item.value',
                'format': 'Value: {}',
              },
            },
          }),
          scopedData,
        );
        expect(result['text'], 'Value: 100');
      });

      test('returns default value for item path when scoped data is empty', () {
        final Map<String, Object?> result = processor.processScoped(
          LayoutNode.fromMap(<String, Object?>{
            'id': 'w1',
            'type': 'Text',
            'properties': <String, Object?>{
              'text': <String, Object?>{r'$bind': 'item.title'},
            },
          }),
          <String, Object?>{},
        );
        expect(result['text'], isNull);
      });
    });
  });
}
