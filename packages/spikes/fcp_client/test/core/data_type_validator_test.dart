// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fcp_client/src/core/data_type_validator.dart';
import 'package:fcp_client/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataTypeValidator', () {
    late DataTypeValidator validator;
    late WidgetCatalog catalog;

    setUp(() {
      validator = DataTypeValidator();
      catalog = WidgetCatalog.fromMap(<String, Object?>{
        'catalogVersion': '1.0.0',
        'items': <String, Object?>{},
        'dataTypes': <String, Map<String, Object>>{
          'user': <String, Object>{
            'type': 'object',
            'properties': <String, Map<String, String>>{
              'name': <String, String>{'type': 'string'},
              'email': <String, String>{'type': 'string', 'format': 'email'},
              'age': <String, String>{'type': 'integer'},
            },
            'required': <String>['name', 'email'],
          },
        },
      });
    });

    test('returns true for valid data', () async {
      final Map<String, Object> data = <String, Object>{
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      };
      final bool isValid = await validator.validate(
        dataType: 'user',
        data: data,
        catalog: catalog,
      );
      expect(isValid, isTrue);
    });

    test(
      'returns false for invalid data (missing required property)',
      () async {
        final Map<String, int> data = <String, int>{'age': 30};
        final bool isValid = await validator.validate(
          dataType: 'user',
          data: data,
          catalog: catalog,
        );
        expect(isValid, isFalse);
      },
    );

    test('returns false for invalid data (wrong type)', () async {
      final Map<String, String> data = <String, String>{
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 'thirty',
      };
      final bool isValid = await validator.validate(
        dataType: 'user',
        data: data,
        catalog: catalog,
      );
      expect(isValid, isFalse);
    });

    test('returns false for invalid data (wrong format)', () async {
      final Map<String, String> data = <String, String>{
        'name': 'Alice',
        'email': 'not-an-email',
      };
      final bool isValid = await validator.validate(
        dataType: 'user',
        data: data,
        catalog: catalog,
      );
      expect(isValid, isFalse);
    });

    test('returns true for a data type not in the catalog', () async {
      final Map<String, String> data = <String, String>{'any': 'data'};
      final bool isValid = await validator.validate(
        dataType: 'unknown_type',
        data: data,
        catalog: catalog,
      );
      expect(isValid, isTrue);
    });
    test('returns true when dataTypes map is empty', () async {
      catalog = WidgetCatalog.fromMap(<String, Object?>{
        'catalogVersion': '1.0.0',
        'items': <String, Object?>{},
        'dataTypes': <String, Object?>{},
      });
      final Map<String, String> data = <String, String>{'any': 'data'};
      final bool isValid = await validator.validate(
        dataType: 'user',
        data: data,
        catalog: catalog,
      );
      expect(isValid, isTrue);
    });
  });
}
