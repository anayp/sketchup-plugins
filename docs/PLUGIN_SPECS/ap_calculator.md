# ap_calculator Spec

## Metadata
- Plugin: ap_calculator
- Owner: TBD
- Priority: P1
- Sprint Target: Sprint 1
- Status: Dead code cleanup + evaluator tests

## 1. Purpose
- Provide a lightweight in-SketchUp calculator for arithmetic expressions.

## 2. Supported Workflows
- User enters expression via dialog keypad/input.
- Expression evaluates and displays result.

## 3. Inputs and Options
- Input: arithmetic expression string.
- Operators: +, -, *, /, ^, parentheses.

## 4. Output and Side Effects
- Result shown in calculator display.
- No model geometry side effects.

## 5. Error Cases and Messages
- Invalid expression returns user-visible error instead of crash.
- Empty input should be rejected cleanly.

## 6. Cross-Platform Rules (Windows + macOS)
- Dialog opens and behaves identically on both platforms.
- No OS-specific dependencies required for evaluation.

## 7. Acceptance Tests
- [x] AT-01 `2+3*4` returns `14` (operator precedence).
- [x] AT-02 `(2+3)*4` returns `20` (parentheses).
- [x] AT-03 `2^3^2` returns `512` (right-associative exponent).
- [x] AT-04 invalid expression (e.g. `2++2`) returns error state.

## 8. Non-Goals and Known Limits
- Non-arithmetic functions are not required in current scope.
- Scientific/engineering mode is out of scope for Sprint 1.

## 9. Defect History
- DEF-001: precedence bug, `2+3*4` returned `20` instead of `14` (resolved in Sprint 1).
- DEF-002: exponent associativity bug, `2^3^2` returned `64` instead of `512` (resolved in Sprint 1).

## 10. Change Log
- 2026-02-17: Initial spec scaffold.
- 2026-02-17: Added test-discovered defects DEF-001 and DEF-002.
- 2026-02-17: Fixed DEF-001 and DEF-002; unit tests green.
