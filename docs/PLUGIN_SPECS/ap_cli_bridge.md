# ap_cli_bridge Spec

## Metadata
- Plugin: `ap_cli_bridge`
- Owner: `user`
- Priority: `P1`
- Sprint Target: `Sprint 2`
- Status: `extended command surface implemented`

## 1. Purpose
- Expose a safe localhost command interface so external CLI/agent tools can query model state without re-implementing SketchUp internals each session.
- Improve snapshot retrieval speed by caching snapshot payloads until model/selection changes.

## 2. Supported Workflows
- Primary flow:
1. User starts bridge from SketchUp menu.
2. CLI client sends JSON request over localhost TCP.
3. Bridge executes whitelisted command on SketchUp main thread and returns JSON response.
- Secondary flow:
1. External workflow repeatedly fetches `snapshot.get`.
2. Bridge returns cached payload when model state is unchanged.

## 3. Inputs and Options
- User inputs:
  - Bridge command string:
    - Core: `help`, `ping`, `bridge.start`, `bridge.stop`, `bridge.status`
    - Model state: `snapshot.get`, `snapshot.refresh`, `selection.summary`, `view.capture`
    - Automation: `batch.run`
    - Advanced: `ruby.eval` (disabled by default)
    - History passthrough: `history.init`, `history.commit`, `history.log`, `history.checkout`, `history.diff`
  - Optional command params JSON.
- Defaults:
  - Host: `127.0.0.1`
  - Port: `7464`
  - Configurable via `AP_CLI_BRIDGE_HOST` and `AP_CLI_BRIDGE_PORT`.
- Validation rules:
  - Request must be valid JSON object with `command`.
  - Unknown commands must fail with structured `invalid_command` error.

## 4. Output and Side Effects
- Geometry/data changes:
  - None for baseline command set.
- Files/preferences changed:
  - None.
- UI feedback:
  - Status text when bridge starts/stops.
  - Plugin menu entries to start/stop/view status.

## 5. Error Cases and Messages
- Invalid input:
  - Invalid JSON returns `invalid_json`.
  - Missing command returns `invalid_request`.
- Missing selection/context:
  - No active model returns `model_unavailable`.
- Recoverable failures:
  - Bridge startup/bind issues return `bridge_start_failed`.
  - Queued requests during shutdown return `bridge_stopped`.

## 6. Cross-Platform Rules (Windows + macOS)
- Path behavior:
  - Returned model path is passthrough from SketchUp model path.
- Dialog/OS interaction:
  - No OS-specific UI dependencies beyond SketchUp menu and status text.
- Known platform differences:
  - Port binding errors can differ by OS; errors are normalized into structured response codes.

## 7. Acceptance Tests
- [x] AT-01 `ping` returns service identity and version.
- [x] AT-02 `snapshot.get` returns cached result until dirty flag is set.
- [x] AT-03 `selection.summary` reports entity-type counts consistently.
- [x] AT-04 `view.capture` writes an image and returns a path.
- [x] AT-05 `batch.run` executes multiple commands and returns per-command results.
- [x] AT-06 `ruby.eval` blocked by default and token-gated when enabled.
- [ ] AT-07 Manual test in SketchUp 2026 on Windows.
- [ ] AT-08 Manual test in SketchUp 2026 on macOS.

## 8. Non-Goals and Known Limits
- Not covered by this plugin:
  - Arbitrary Ruby eval from external clients.
  - Remote/non-localhost network exposure.
- Current limitations:
  - Baseline protocol is newline-delimited JSON over raw TCP (no auth layer yet).
  - Snapshot invalidation relies on observers plus explicit dirty paths.
  - `ruby.eval` is intentionally high-trust and must remain opt-in.

## 9. Change Log
- 2026-02-19: Baseline bridge, command whitelist, queue-based main-thread execution, and unit tests added.
- 2026-02-24: Added render capture, batch command execution, guarded eval, and model-history RPC commands.
