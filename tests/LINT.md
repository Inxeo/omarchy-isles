# QML lint

Run `python3 tests/run-lint.py` on an Omarchy installation. This checks all root runtime QML files; the QML integration fixtures are exercised by `run-integration.py` instead.

The runner selects `/usr/lib/qt6/bin/qmllint` explicitly. On the tested machine, `/usr/bin/qmllint` belongs to Qt 5 and is unsuitable for this Qt 6 plugin. Set `QMLLINT` to another Qt 6 executable if needed. `OMARCHY_PATH` selects the installed host tree (default `/usr/share/omarchy`). No desktop session is needed.

Quickshell supplies the `qs` namespace at runtime. The runner temporarily maps `qs` to the actual installed shell directory, letting Qt resolve `qs.Ui` and `qs.Commons` and their real component definitions. It does not modify the installed host or substitute fake types. User lint settings are ignored and the warning threshold is zero.

## Reviewed diagnostics

The baseline was inspected with Qt 6.12.0 and Omarchy 4.5.0-3. Import/type-resolution errors are not accepted. Remaining exact diagnostics are recorded in `qml-lint-baseline.json`:

- `missing-property`: Omarchy exposes bar/theme objects as generic QObject/QtObject types. The members used here exist in the injected bar API, `Commons/Style.qml`, and `Commons/Color.qml`. Quickshell's window reference also loses the concrete window type during static analysis, producing `contentItem` warnings on the paint-root lookup. Measurement maps slots onto that strip item rather than `window.contentItem` directly. Real component integration tests cover these accesses; this does not make every possible dynamic access statically safe.
- `unqualified`: nested render components refer to IDs in their creation context (`root`, `chip`, and `box`). These are intentional existing QML scope relationships, covered by renderer integration tests. Adding `ComponentBehavior: Bound` would alter component semantics; it is not applied merely to silence these warnings.
- `unused-imports` (informational): existing imports retained without changing runtime code solely for lint cleanliness.
- `block-scope-var-declaration`: measurement uses `var` inside `try`/`if` blocks in the same ES5 style as the rest of the plugin. These are not converted to `let`/`const` solely to silence lint.

A passing run means **imports resolved and no new diagnostics**, not warning-free lint. The runner matches file, diagnostic category/severity/message, exact source line, column, and occurrence count. New diagnostics fail; disappearing or changed baseline entries also require review. It does not globally suppress warning categories or automatically refresh the baseline. Syntax/import failures, missing tooling, and incomplete reports fail the check.

After a source or host upgrade, inspect differences and update individual baseline entries only with an explanation. Continue running the QML integration suite for dynamic properties and nested rendering. Standalone JavaScript regression checks remain separate.

Auto contrast adds reviewed accesses to `PluginBarApi.barForeground`, `Color.bar.text`, and the existing caption font token, plus renderer references to the outer contrast properties. These use the same generic host types and creation-context scope described above; the integration suite checks live foreground changes and independent surfaces.

The menu rebuild uses host `Toggle`, `PanelSectionHeader`, `PanelSeparator`, and `ConfirmDialog`. Nested look/border chips refer to the flow id and outer `root` in the same creation-context way as the renderers. Theme colours are read as `Commons.Color` so Qt 6.12’s `Color` value type cannot steal `pick`, `bar`, or `background`. New or moved diagnostics from that layout belong in the baseline only after review.

Omarchy 4.5 paint-root lookup still reads `window.contentItem` once to find the bar strip. Measurement then uses that strip item’s size, so the old `window.contentItem.width` diagnostics on the huddle key and draw call were removed as stale. `PluginBarApi.position` is read so the binding retriggers when the bar moves to another edge; it is the same generic host type as `barForeground`.
