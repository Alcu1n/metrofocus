"""Run from repository root with the preview server already listening on 8768."""
from pathlib import Path
import subprocess

cli = str(Path.home() / '.codex/skills/playwright/scripts/playwright_cli.sh')
replay = Path(__file__).with_name('replay.js').read_text()
subprocess.run([cli, '-s=metrofocus-design', 'open', 'http://127.0.0.1:8768/index.html'], check=True)
subprocess.run([cli, '-s=metrofocus-design', 'run-code', replay], check=True)
subprocess.run([cli, '-s=metrofocus-design', 'eval', 'window.__verification'], check=True)
