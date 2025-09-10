// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dart_schema_builder/dart_schema_builder.dart' show S, Schema;
import 'package:fcp_client/fcp_client.dart';
import 'package:meta/meta.dart';

import '../ai_client/ai_client.dart';
import '../model/chat_message.dart';

class GenUiManager {
  GenUiManager({required this.aiClient, this.showInternalMessages = false});

  final bool showInternalMessages;

  final AiClient aiClient;

  @visibleForTesting
  List<ChatMessage> get chatHistoryForTesting => _chatHistory;

  final _chatHistory = <ChatMessage>[];

  int _outstandingRequests = 0;

  final StreamController<DynamicUIPacket> _uiPacketStreamController =
      StreamController<DynamicUIPacket>.broadcast();
  final StreamController<LayoutUpdate> _layoutUpdateStreamController =
      StreamController<LayoutUpdate>.broadcast();
  final StreamController<StateUpdate> _stateUpdateStreamController =
      StreamController<StateUpdate>.broadcast();
  final StreamController<bool> _loadingStreamController =
      StreamController<bool>.broadcast();

  Stream<DynamicUIPacket> get uiPacketStream =>
      _uiPacketStreamController.stream;
  Stream<LayoutUpdate> get layoutUpdateStream =>
      _layoutUpdateStreamController.stream;
  Stream<StateUpdate> get stateUpdateStream =>
      _stateUpdateStreamController.stream;
  Stream<bool> get loadingStream => _loadingStreamController.stream;

  void dispose() {
    _uiPacketStreamController.close();
    _layoutUpdateStreamController.close();
    _stateUpdateStreamController.close();
    _loadingStreamController.close();
  }

  Future<void> sendUserPrompt(String prompt) async {
    if (prompt.isEmpty) {
      return;
    }
    _chatHistory.add(UserMessage.text(prompt));
    return _generateAndSendResponse();
  }

  void handleEvent(EventPayload event) {
    if (event.eventName == 'filterOptionSelected') {
      final statePath = event.arguments?['statePath'] as String?;
      final value = event.arguments?['value'];
      if (statePath != null) {
        final stateUpdate = StateUpdate.fromMap({
          'patches': [
            {'op': 'replace', 'path': '/$statePath', 'value': value},
          ],
        });
        _stateUpdateStreamController.add(stateUpdate);
      }
      return;
    }

    final toolResult = ToolResultPart(
      callId: event.sourceNodeId,
      result: jsonEncode(event.toJson()),
    );

    final messageParts = <MessagePart>[
      toolResult,
      ThinkingPart(
        'The user has triggered the "${event.eventName}" event from the UI '
        'element with ID "${event.sourceNodeId}". Consolidate the UI events '
        'and update the UI accordingly.',
      ),
    ];

    _chatHistory.add(UserMessage(messageParts));
    _generateAndSendResponse();
  }

  Future<void> _generateAndSendResponse() async {
    _outstandingRequests++;
    _loadingStreamController.add(true);
    try {
      final response = await aiClient.generateContent(
        _chatHistory,
        outputSchema,
      );
      if (response == null) {
        return;
      }
      final responseMap = response as Map<String, Object?>;

      _convertListsToMaps(responseMap);

      final ui = responseMap['ui'] as Map<String, Object?>?;
      final patches = responseMap['patches'] as Map<String, Object?>?;

      if (ui != null) {
        // If we have a UI packet, we apply any layout patches to it before
        // sending it.
        if (patches?['layoutUpdate']
            case final Map<String, Object?> layoutUpdate) {
          _applyLayoutPatch(ui, layoutUpdate);
        }
        _uiPacketStreamController.add(DynamicUIPacket.fromMap(ui));
      } else if (patches?['layoutUpdate']
          case final Map<String, Object?> layoutUpdate) {
        // If there is no UI packet, send the layout update as a patch.
        _layoutUpdateStreamController.add(LayoutUpdate.fromMap(layoutUpdate));
      }

      // State updates can always be sent as patches.
      if (patches?['stateUpdate'] case final Map<String, Object?> stateUpdate) {
        _stateUpdateStreamController.add(StateUpdate.fromMap(stateUpdate));
      }
    } catch (e) {
      // TODO(gspencer): Use a logging framework.
      // print('Error generating content: $e');
      _chatHistory.add(AssistantMessage.text('Error: $e'));
    } finally {
      _outstandingRequests--;
      if (_outstandingRequests == 0) {
        _loadingStreamController.add(false);
      }
    }
  }

  void _applyLayoutPatch(
    Map<String, Object?> ui,
    Map<String, Object?> layoutUpdate,
  ) {
    if (ui['layout'] case final Map<String, Object?> layout) {
      if (layout['nodes'] case final List<Object?> nodes) {
        final nodeMap = {
          for (final node in nodes)
            if (node is Map<String, Object?>) node['id']: node,
        };
        if (layoutUpdate['operations'] case final List<Object?> operations) {
          for (final operation in operations) {
            if (operation is Map<String, Object?>) {
              if (operation['op'] == 'add') {
                final targetNodeId = operation['targetNodeId'] as String?;
                final targetNode = nodeMap[targetNodeId];
                if (targetNode != null) {
                  if (targetNode['properties']
                      case final Map<String, Object?> properties) {
                    if (properties[operation['targetProperty']]
                        case final List<Object?> children) {
                      if (operation['nodes']
                          case final List<Object?> newNodes) {
                        children.addAll(newNodes);
                        nodes.addAll(newNodes);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Schema get outputSchema {
    final layoutNodeSchema = S.object(
      description: 'A single node in the UI layout.',
      properties: {
        'id': S.string(
          description:
              'The unique identifier for the node (widget instance). Should be lower_snake_case.',
        ),
        'type': S.string(
          description:
              'The type of the widget, which must match a widget type in the widget catalog.',
        ),
        'properties': S.list(
          description:
              'A list of key-value pairs representing static properties for the node, corresponding to widget properties. All required widget properties must be included.',
          items: S.object(
            properties: {
              'key': S.string(description: 'The name of the property.'),
              'value': S.any(description: 'The property value.'),
            },
            required: ['key', 'value'],
          ),
        ),
        'bindings': S.list(
          description:
              'A list of key-value pairs that bind widget properties to values in the state object.',
          items: S.object(
            properties: {
              'key': S.string(description: 'The name of the property to bind.'),
              'value': S.object(
                description:
                    'A Binding object, which has a required "path" and optional "format", "condition", or "map" transformations.',
                properties: {
                  'path': S.string(
                    description:
                        'The JSON Pointer path to the value in the state object.',
                  ),
                  'format': S.string(
                    description:
                        'A format string to apply to the value (e.g. for dates or numbers).',
                  ),
                  'condition': S.string(
                    description:
                        'A condition to evaluate. If the condition is not met, the binding is not applied.',
                  ),
                  'map': S.list(
                    description:
                        'A list of key-value pairs to map the input value to an output value.',
                    items: S.object(
                      properties: {
                        'key': S.string(
                          description: 'The input value to match.',
                        ),
                        'value': S.any(
                          description:
                              'The output value to use if the input value matches.',
                        ),
                      },
                      required: ['key', 'value'],
                    ),
                  ),
                },
                required: ['path'],
              ),
            },
            required: ['key', 'value'],
          ),
        ),
        'itemTemplate': S.object(
          description:
              'For list-building widgets that have multiple children, this defines the layout node template for each item. It has the same structure as a layout node.',
          properties: {
            'id': S.string(
              description:
                  'The unique identifier for the item template. Should be lower_snake_case.',
            ),
            'type': S.string(
              description:
                  'The type of the item template, corresponding to a widget type.',
            ),
            'properties': S.list(
              description:
                  'A list of key-value pairs representing static properties for the item template.',
              items: S.object(
                properties: {
                  'key': S.string(description: 'The name of the property.'),
                  'value': S.any(description: 'The property value.'),
                },
                required: ['key', 'value'],
              ),
            ),
            'bindings': S.list(
              description:
                  'A list of key-value pairs that bind widget properties to values in the state object for the item template.',
              items: S.object(
                properties: {
                  'key': S.string(
                    description: 'The name of the property to bind.',
                  ),
                  'value': S.object(
                    description:
                        'A Binding object, which has a required "path" and optional "format", "condition", or "map" transformations.',
                    properties: {
                      'path': S.string(
                        description:
                            'The JSON Pointer path to the value in the state object.',
                      ),
                      'format': S.string(
                        description:
                            'A format string to apply to the value (e.g. for dates or numbers).',
                      ),
                      'condition': S.string(
                        description:
                            'A condition to evaluate. If the condition is not met, the binding is not applied.',
                      ),
                      'map': S.list(
                        description:
                            'A list of key-value pairs to map the input value to an output value.',
                        items: S.object(
                          properties: {
                            'key': S.string(
                              description: 'The input value to match.',
                            ),
                            'value': S.any(
                              description:
                                  'The output value to use if the input value matches.',
                            ),
                          },
                          required: ['key', 'value'],
                        ),
                      ),
                    },
                    required: ['path'],
                  ),
                },
                required: ['key', 'value'],
              ),
            ),
          },
          required: ['id', 'type'],
        ),
      },
      required: ['id', 'type'],
    );

    final layoutUpdateSchema = S.object(
      description: 'An update to the UI layout structure.',
      properties: {
        'operations': S.list(
          description: 'A list of operations to perform on the UI layout.',
          items: S.object(
            description: 'A single operation to perform on the UI layout.',
            properties: {
              'op': S.string(
                description:
                    'The type of operation to perform. Can be "add", "remove", or "replace".',
                enumValues: ['add', 'remove', 'replace'],
              ),
              'nodes': S.list(
                description:
                    'A list of layout node objects to add or update. Used with "add" and "replace" operations.',
                items: layoutNodeSchema,
              ),
              'nodeIds': S.list(
                description:
                    'A list of node IDs to remove from the UI. Only used with the "remove" operation.',
                items: S.string(
                  description: 'The unique identifier for the node to remove.',
                ),
              ),
              'targetNodeId': S.string(
                description:
                    'The ID of the node to which an "add" operation is applied. This is the parent node.',
              ),
              'targetProperty': S.string(
                description:
                    'The property of the target node to which new nodes are added (e.g., "children"). Used with "add".',
              ),
            },
            required: ['op'],
          ),
        ),
      },
      required: ['operations'],
    );

    final stateUpdateSchema = S.object(
      description: 'A JSON Patch (RFC 6902) update to the UI state.',
      properties: {
        'patches': S.list(
          description:
              'A list of JSON Patch operations to apply to the UI state.',
          items: S.object(
            description:
                'A single JSON Patch operation. See RFC 6902 for more details.',
            properties: {
              'op': S.string(
                enumValues: ['add', 'remove', 'replace'],
                description: 'The operation to perform.',
              ),
              'path': S.string(
                description:
                    'The JSON Pointer path to the value to operate on.',
              ),
              'value': S.combined(
                anyOf: [
                  S.string(),
                  S.integer(),
                  S.number(),
                  S.boolean(),
                  S.object(additionalProperties: true),
                  S.list(items: S.any()),
                  S.nil(),
                ],
                description:
                    'The value to apply. For "add", "replace", and "test" operations.',
              ),
            },
            required: ['op', 'path'],
          ),
        ),
      },
      required: ['patches'],
    );

    return S.object(
      description:
          'A schema for creating or updating the UI. The "ui" property is used for the initial build or full replacement, and "patches" can be used for subsequent partial updates. If both are present, "ui" is applied first, then "patches".',
      properties: {
        'ui': S.object(
          description:
              'The complete UI definition. Can be used for initial build or to completely replace the UI.',
          properties: {
            'layout': S.object(
              description: 'The layout definition.',
              properties: {
                'root': S.string(
                  description: 'The ID of the root layout node.',
                ),
                'nodes': S.list(
                  description: 'A list of all layout nodes.',
                  items: layoutNodeSchema,
                ),
              },
              required: ['root', 'nodes'],
            ),
            'state': S.list(
              description:
                  'A list of key-value pairs representing the initial state of the UI.',
              items: S.object(
                properties: {
                  'key': S.string(description: 'The name of the property.'),
                  'value': S.any(description: 'The value of the property.'),
                },
                required: ['key', 'value'],
              ),
            ),
          },
          required: ['layout', 'state'],
        ),
        'patches': S.object(
          description:
              'A set of patches to apply to the existing UI. Can be applied after a "ui" definition in the same response.',
          properties: {
            'layoutUpdate': layoutUpdateSchema,
            'stateUpdate': stateUpdateSchema,
          },
        ),
      },
    );
  }

  void _convertListsToMaps(Map<String, Object?> data) {
    if (data['ui'] case final Map<String, Object?> ui) {
      if (ui['layout'] case final Map<String, Object?> layout) {
        if (layout['nodes'] case final List<Object?> nodes) {
          for (final node in nodes) {
            if (node is Map<String, Object?>) {
              _convertNode(node);
            }
          }
        }
      }
      if (ui['state'] case final List<Object?> state) {
        ui['state'] = _kvListToMap(state);
      }
    }
    if (data['patches'] case final Map<String, Object?> patches) {
      if (patches['layoutUpdate']
          case final Map<String, Object?> layoutUpdate) {
        if (layoutUpdate['operations'] case final List<Object?> operations) {
          for (final operation in operations) {
            if (operation is Map<String, Object?>) {
              if (operation['nodes'] case final List<Object?> nodes) {
                for (final node in nodes) {
                  if (node is Map<String, Object?>) {
                    _convertNode(node);
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  void _convertNode(Map<String, Object?> node) {
    if (node['properties'] case final List<Object?> properties) {
      node['properties'] = _kvListToMap(properties);
    }
    if (node['bindings'] case final List<Object?> bindingsList) {
      final bindingsMap = <String, Object?>{};
      for (final item in bindingsList) {
        if (item is Map<String, Object?> && item.containsKey('key')) {
          final key = item['key']! as String;
          if (item['value'] case final Map<String, Object?> value) {
            if (value['map'] case final List<Object?> mapList) {
              value['map'] = _kvListToMap(mapList);
            }
            bindingsMap[key] = value;
          }
        }
      }
      node['bindings'] = bindingsMap;
    }
    if (node['itemTemplate'] case final Map<String, Object?> itemTemplate) {
      _convertNode(itemTemplate);
    }
  }

  Map<String, Object?> _kvListToMap(List<Object?> list) {
    final map = <String, Object?>{};
    for (final item in list) {
      if (item is Map<String, Object?> && item.containsKey('key')) {
        map[item['key']! as String] = item['value'];
      }
    }
    return map;
  }
}
