#!/usr/bin/env python3
"""Qt 6 QML lint with real Omarchy imports and an explicit diagnostic baseline."""
import collections
import json
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
linter = os.environ.get('QMLLINT', '/usr/lib/qt6/bin/qmllint')
version = subprocess.check_output([linter, '--version'], text=True).strip()
if not version.startswith('qmllint 6.'):
    raise SystemExit('Qt 6 qmllint is required; QMLLINT can select its executable.')
for module in ('Ui', 'Commons'):
    if not (shell / module / 'qmldir').is_file():
        raise SystemExit(f'Missing installed Omarchy module: {shell / module}')
files = sorted(p.name for p in project.glob('*.qml'))
with tempfile.TemporaryDirectory(prefix='isles-qmllint-') as directory:
    work = Path(directory)
    (work / 'qs').symlink_to(shell, target_is_directory=True)
    output = work / 'report.json'
    result = subprocess.run([linter, '--ignore-settings', '--max-warnings', '0',
                             '-I', str(work), '--json', str(output), *files],
                            cwd=project, capture_output=True, text=True)
    if not output.exists():
        raise SystemExit(result.stdout + result.stderr or 'qmllint produced no report')
    report = json.loads(output.read_text())
    if result.returncode not in (0, 255):
        raise SystemExit(f'Unexpected qmllint exit {result.returncode}: {result.stderr}')
    if sorted(f['filename'] for f in report['files']) != files:
        raise SystemExit('Incomplete qmllint report')
    actual = []
    for file in report['files']:
        lines = (project / file['filename']).read_text().splitlines()
        if not file['success'] and not file['warnings']:
            raise SystemExit(f"Unexplained lint failure: {file['filename']}")
        for warning in file['warnings']:
            actual.append([file['filename'], warning['id'], warning['type'],
                           warning['message'], lines[warning['line'] - 1].strip(),
                           warning['column']])
    if result.returncode and not actual:
        raise SystemExit('qmllint failed without diagnostics')

baseline = json.loads((project / 'tests/qml-lint-baseline.json').read_text())
expected = collections.Counter(tuple(row) for row in baseline['diagnostics'])
observed = collections.Counter(tuple(row) for row in actual)
new, stale = observed - expected, expected - observed
for label, differences in [('NEW', new), ('STALE baseline', stale)]:
    for row, count in differences.items():
        print(f'{label} ({count}): {row}')
if new or stale:
    raise SystemExit('FAIL: review diagnostics and baseline; do not update it blindly.')
print(f'PASS: {version}; {len(files)} runtime QML files; imports resolved; '
      f'{len(actual)} explicitly recorded diagnostics, no new or stale entries.')
print('This is a baseline check, not warning-free lint. See tests/LINT.md.')
