# Changelog

## 0.4.0

### Added

- Preset dropdown with six theme-aware styles: Glowy, Halo, Pebbles, Underline, Arrowhead, and Blueprint.
- Save named personal presets and update an existing personal preset by name. Presets are stored in the widget's `savedPresets` setting in `shell.json`.
- Automatic preset matching and a Custom label after manual adjustments. A selected personal preset keeps its name when its settings also match a built-in preset.
- Scrollable panel content for smaller displays.
- Sequential settings writes through the Omarchy CLI, with completion and failure feedback.
- Regression checks for defaults, preset matching, saving/updating, JSON round-trips, malformed preset data, drawing behaviour, and polling settlement.

### Changed

- New installs start with Glowy: Glow, bottom border, fill 66%, stroke opacity 58%, stroke width 0px, padding 1px, and radius 100%. The zero stroke width means no outline is drawn.
- Explicit existing appearance settings remain in place. Presets change appearance only; the master islands toggle stays independent.
- Added OpenAI Codex to the README credits for AI-assisted development and review.

### Fixed

- Unchanged geometry no longer restarts the 400ms settling timer. Measurement returns from 50ms burst polling to the intended 250ms idle interval after changes stop, reducing scheduled idle scans from about 20 to 4 per second. Live CPU savings have not been benchmarked.
- Stroke opacity of 0% remains transparent instead of falling back to 100%.
- Ends borders produce the intended pointed shapes for Pills and Rail as well as Cluster and Glow.

### Validation

- Original three fixes visually checked by the maintainer on Omarchy 4.0.4-1.
- Automated JavaScript checks cover preset logic and drawing regressions in both orientations, plus polling settlement.
- An isolated Quickshell panel test loaded the panel, applied a preset, and exercised personal-preset writes with a mock CLI; reloaded settings selected the saved preset correctly.
- Full visual acceptance of the new presets and save workflow remains a maintainer check before publication.
