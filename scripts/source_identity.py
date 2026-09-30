#!/usr/bin/env python3
"""Create an inspectable source identity without requiring a Git repository."""
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
paths = []
for directory in ('MetroFocus', 'MetroFocusLiveActivity', 'MetroFocusTests', 'MetroFocusUITests', 'MetroFocus.xcodeproj', 'scripts'):
    paths.extend(p for p in (root / directory).rglob('*') if p.is_file() and 'xcuserdata' not in p.parts and '__pycache__' not in p.parts)
entries = [f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(root)}' for p in sorted(paths)]
manifest = '\n'.join(entries) + '\n'
(root / 'artifacts/source-sha256.txt').write_text(manifest)
print(hashlib.sha256(manifest.encode()).hexdigest())
