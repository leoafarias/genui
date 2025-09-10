# Refactor Implementation Plan: FCP Client Streaming Protocol Migration

This document outlines the step-by-step plan to refactor the `fcp_client` package to align with the GenUI Streaming Protocol (GSP).

## Phased Implementation

### Phase 1: Foundational Model Creation

The goal of this phase is to create all the necessary Dart data models for parsing the JSONL stream and handling GSP messages, and to adjust the existing models to the new specification.

- [ ] **Task 1.1: Create `streaming_models.dart`**: Create a new file `packages/spikes/fcp_client/lib/src/models/streaming_models.dart` to define the new GSP message types.
  - Define a sealed `StreamMessage` class.
  - Define `StreamHeader`, `Layout`, `LayoutRoot`, and `StateUpdate` as subclasses or implementations of `StreamMessage`.
  - Define the `ClientRequest`, `Event`, and `UnknownCatalogError` models.
- [ ] **Task 1.2: Update `LayoutNode`**: Modify the existing `LayoutNode` model in `packages/spikes/fcp_client/lib/src/models/models.dart`.
  - Remove the `bindings` map.
  - Update the logic to handle bindings directly within the `properties` map, where a property value is a map containing a `"$bind"` key.
- [ ] **Task 1.3: Update `BindingProcessor`**: Modify the `BindingProcessor` in `packages/spikes/fcp_client/lib/src/core/binding_processor.dart` to reflect the `LayoutNode` changes. It should now look for binding objects within the `properties` map instead of a separate `bindings` map.
- [ ] **Task 1.4: Remove Obsolete Models**: Delete the old `StateUpdate`, `LayoutUpdate`, and `DynamicUIPacket` models from `packages/spikes/fcp_client/lib/src/models/models.dart`. Also remove the `FcpViewController` which is now obsolete.
- [ ] **Task 1.5: Update Tests**: Update any unit tests in `packages/spikes/fcp_client/test/` that are now broken due to the model changes. This will likely involve `models_test.dart` and `binding_processor_test.dart`.

#### Post-Phase 1 Actions

-   [ ] Run `dart_fix` and `dart_format` on the modified files.
-   [ ] Run `analyze_files` and fix any issues.
-   [ ] Run all tests in `packages/spikes/fcp_client/test/` to ensure they pass.
-   [ ] Run `dart_format` again.
-   [ ] Present a `git diff` and a commit message for approval.
-   [ ] Update the Journal.
-   [ ] Wait for approval before proceeding.

### Phase 2: Implement the `GspInterpreter`

This phase focuses on creating the core logic for processing the incoming JSONL stream.

- [ ] **Task 2.1: Create `gsp_interpreter.dart`**: Create the `GspInterpreter` class in a new file `packages/spikes/fcp_client/lib/src/core/gsp_interpreter.dart`.
  - Implement the constructor to accept a `Stream<String>` and a `WidgetCatalog`.
  - Add the internal state properties: `_nodeBuffer`, `_state`, `_rootId`, and `_isReadyToRender`.
  - Add the public getters: `currentLayout`, `currentState`, and `isReadyToRender`.
- [ ] **Task 2.2: Implement Stream Handling**: Implement the logic to listen to the stream and parse each line as JSON.
- [ ] **Task 2.3: Implement Message Dispatching**: Create private handler methods (`_handleStreamHeader`, `_handleLayout`, `_handleLayoutRoot`, `_handleStateUpdate`) and the main `processMessage` method to dispatch messages to them.
- [ ] **Task 2.4: Implement State Management**: Implement the logic within the handler methods to correctly update the internal state (`_nodeBuffer`, `_state`, etc.) and call `notifyListeners()` when the UI should be updated.
- [ ] **Task 2.5: Write Unit Tests**: Create `packages/spikes/fcp_client/test/core/gsp_interpreter_test.dart` to thoroughly test the `GspInterpreter`.
  - Test that it correctly parses and dispatches all message types.
  - Test that it correctly initializes state from the `StreamHeader`.
  - Test that it buffers `LayoutNode`s correctly.
  - Test that `isReadyToRender` becomes true at the correct time.
  - Test that state updates are applied correctly.

#### Post-Phase 2 Actions

-   [ ] Run `dart_fix` and `dart_format` on the new and modified files.
-   [ ] Run `analyze_files` and fix any issues.
-   [ ] Run all tests to ensure they pass.
-   [ ] Run `dart_format` again.
-   [ ] Present a `git diff` and a commit message for approval.
-   [ ] Update the Journal.
-   [ ] Wait for approval before proceeding.

### Phase 3: Refactor the View Layer

This phase adapts the UI-facing components to the new streaming architecture.

- [ ] **Task 3.1: Rename and Refactor `FcpView` to `GenUiView`**:
  - Rename the file `packages/spikes/fcp_client/lib/src/widgets/fcp_view.dart` to `genui_view.dart`.
  - In the new file, rename the `FcpView` widget to `GenUiView`.
  - Change its constructor to accept a `GspInterpreter` instead of a `DynamicUIPacket`.
  - Update the state class (`_GenUiViewState`) to listen to the interpreter and call `setState` on notification.
  - Modify the `build` method to show a loading indicator until `interpreter.isReadyToRender` is true, and then build the UI using the interpreter's layout.
- [ ] **Task 3.2: Update Event Handling**:
  - Modify the `onEvent` callback to provide a complete `ClientRequest` object.
  - Update the `FcpProvider` (consider renaming to `GenUiProvider`) to pass down the new `onEvent` callback signature.
- [ ] **Task 3.3: Update `_LayoutEngine`**: The internal `_LayoutEngine` will need to be adjusted to get its layout and state information from the `GspInterpreter` instead of a static packet.
- [ ] **Task 3.4: Update Widget and Integration Tests**: Refactor the tests in `packages/spikes/fcp_client/test/widgets/` to work with the new `GenUiView` and `GspInterpreter`. This will involve creating mock interpreters or streams for testing purposes.

#### Post-Phase 3 Actions

-   [ ] Run `dart_fix` and `dart_format`.
-   [ ] Run `analyze_files` and fix any issues.
-   [ ] Run all tests to ensure they pass.
-   [ ] Run `dart_format` again.
-   [ ] Present a `git diff` and a commit message for approval.
-   [ ] Update the Journal.
-   [ ] Wait for approval before proceeding.

### Phase 4: Update the Example Application

The final phase is to update the example app to use the new streaming client.

- [ ] **Task 4.1: Update `main.dart`**: Modify `packages/spikes/fcp_client/example/lib/main.dart`.
  - Remove the old `FcpViewController` and the text fields for manual JSON updates.
  - Instantiate a `GspInterpreter` with a sample `Stream<String>` that emits a valid JSONL sequence.
  - Replace the `FcpView` with the new `GenUiView`, passing it the interpreter.
  - Implement the `onEvent` callback on `GenUiView` to handle the `ClientRequest` (e.g., by printing it to the console).
- [ ] **Task 4.2: Clean up Example Code**: Remove any obsolete widgets or helper files from the example that were related to the old manual update mechanism.

#### Post-Phase 4 Actions

- [ ] Run `dart_fix` and `dart_format`.
- [ ] Run `analyze_files` and fix any issues.
- [ ] Manually verify the example app runs and displays the UI correctly.
- [ ] Run `dart_format` again.
- [ ] Present a `git diff` and a commit message for approval.
- [ ] Update the Journal.
- [ ] Wait for approval.

---

## Journal

_This section will be updated after each phase to track the progress and any learnings from the implementation._
