#!/usr/bin/env python3
"""Run real QML against a mock scoped API and temporary config; requires Wayland."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
with tempfile.TemporaryDirectory(prefix='isles-integration-') as directory:
    work = Path(directory)
    for name in ('Commons', 'Ui', 'services'):
        (work / name).symlink_to(shell / name, target_is_directory=True)
    (work / 'Isles').symlink_to(project, target_is_directory=True)
    (work / 'home/.config/omarchy').mkdir(parents=True)
    (work / 'home/.config/omarchy/shell.json').write_text('{}')
    env = dict(os.environ, HOME=str(work / 'home'), QT_QPA_PLATFORM='wayland')
    for source, marker in [('integration.qml','ISLES_INTEGRATION_PASS'),('restart.qml','ISLES_RESTART_PASS')]:
        shutil.copyfile(project / 'tests' / source, work / 'shell.qml')
        result = subprocess.run(['quickshell','-p',str(work),'--no-color'],env=env,capture_output=True,text=True,timeout=20)
        output = result.stdout + result.stderr
        print(output, end='')
        errors = ('ISLES_FAIL:', 'ReferenceError:', 'TypeError:', 'Binding loop', 'Unable to assign', 'Failed to load configuration')
        if result.returncode or marker not in output or any(error in output for error in errors):
            raise SystemExit('Integration test failed')
print('PASS: real QML, atomic settings, recovery, multi-surface rendering, and saved presets across restart.')
