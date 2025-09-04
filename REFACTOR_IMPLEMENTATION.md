# Refactor Implementation: Stateless GenUI Server

This document outlines the step-by-step plan to refactor the GenUI client and server to a stateless architecture.

## Phased Implementation Plan

### Phase 1: Server-Side Refactoring (`genui_server`)

- [ ] **Update Schemas**: In `packages/genui_server/src/schemas.ts`, remove `startSessionRequestSchema` and modify `generateUiRequestSchema` to remove `sessionId` and add `catalog`.
- [ ] **Remove Session Flow**: Delete the `packages/genui_server/src/session.ts` file.
- [ ] **Update Server Index**: In `packages/genui_server/src/index.ts`, remove the `startSessionFlow` from the `flows` array.
- [ ] **Remove Caching Logic**: Delete the `packages/genui_server/src/cache.ts` file.
- [ ] **Update Generate Flow**: In `packages/genui_server/src/generate.ts`, update the `generateUiFlow` to get the `catalog` from the request body instead of the cache. Remove all cache-related logic and imports.
- [ ] **Update Tests**:
  - [ ] Delete `packages/genui_server/src/test/session.test.ts`.
  - [ ] Delete `packages/genui_server/src/test/fake-cache-service.ts`.
  - [ ] Update `packages/genui_server/src/test/generate.test.ts` to align with the new stateless `generateUiFlow` and remove any session or cache-related test setup.
- [ ] **Remove Firebase Dependencies**:
  - [ ] In `packages/genui_server/src/genkit.ts`, remove the `firebase-admin/app` import and the `initializeApp()` call.
  - [ ] In `packages/genui_server/package.json`, remove the `firebase-admin` dependency.
  - [ ] Run `pnpm install` within the `packages/genui_server` directory to update the lockfile.

#### Post-Phase 1 Steps

- [ ] Run `pnpm exec eslint . --fix` and `pnpm exec prettier . --write` in `packages/genui_server` to clean up the code.
- [ ] Run `pnpm exec jest` in `packages/genui_server` to ensure all tests pass.
- [ ] Use `git diff` to verify the changes, create a suitable commit message, and present it for approval.
- [ ] Update the "Journal" section below with the current state.
- [ ] Wait for approval before proceeding.

---

### Phase 2: Client-Side Refactoring (`genui_client`)

- [ ] **Update `GenUIClient`**:
  - [ ] In `packages/genui_client/lib/src/genui_client.dart`, remove the `startSession` method.
  - [ ] Modify the `generateUI` method to remove the `sessionId` parameter and add a `Catalog catalog` parameter.
  - [ ] Update the `generateUI` method's request body to include the catalog schema and remove the `sessionId`.
- [ ] **Update `UiAgent`**:
  - [ ] In `packages/genui_client/lib/src/ui_agent.dart`, remove the `_sessionId` field and the `startSession` method.
  - [ ] Update the `sendRequest` and `sendUiEvents` methods to call the modified `_client.generateUI`, passing in the `_genUiManager.catalog`.

#### Post-Phase 2 Steps

- [ ] Run `dart_fix` and `dart_format` tools on the `packages/genui_client` directory.
- [ ] Run the `analyze_files` tool on the `packages/genui_client` directory and fix any issues.
- [ ] Run any tests in `packages/genui_client/test` to make sure they all pass.
- [ ] Run `dart_format` again on the `packages/genui_client` directory.
- [ ] Use `git diff` to verify the changes, create a suitable commit message, and present it for approval.
- [ ] Update the "Journal" section below with the current state.
- [ ] Wait for approval before proceeding.

---

### Phase 3: Update Example Application and Final Cleanup

- [ ] **Update Example**: In `packages/genui_client/example/lib/main.dart`, remove any calls to `agent.startSession()`.
- [ ] **Final Verification**: Run the example application to ensure the end-to-end flow works as expected.
- [ ] **Update Docs**: Update `packages/genui_client/IMPLEMENTATION.md` and `packages/genui_server/IMPLEMENTATION.md` to match the new design.

#### Post-Phase 3 Steps

- [ ] Run `dart_fix` and `dart_format` tools on the `packages/genui_client/example` directory.
- [ ] Run the `analyze_files` tool on the `packages/genui_client/example` directory and fix any issues.
- [ ] Use `git diff` to verify the changes, create a suitable commit message, and present it for approval.
- [ ] Update the "Journal" section below with the final state.
- [ ] Wait for approval to complete the refactor.

---

## Journal

### Initial State

- The implementation plan has been created and is ready for review. No code changes have been made yet.
