"""Check relocation and standalone configuration without a toolchain or hardware run."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

CORE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('core_paths', CORE / 'tools/paths.py')
paths = importlib.util.module_from_spec(spec)
spec.loader.exec_module(paths)
FORGE = paths.FORGE_ROOT

class CoreWorkspace(unittest.TestCase):
    def test_resources_match_pinned_checksums(self):
        for entry in json.loads((CORE / 'res/manifest.json').read_text())['resources']:
            with self.subTest(resource=entry['path']):
                self.assertEqual(hashlib.sha256((CORE / entry['path']).read_bytes()).hexdigest(), entry['sha256'])

    def test_standalone_core_uses_explicit_shared_workspace(self):
        with tempfile.TemporaryDirectory(dir=CORE / 'tmp') as tmp:
            extracted = Path(tmp) / 'extracted'
            (extracted / 'tools').mkdir(parents=True)
            shutil.copyfile(CORE / 'tools/paths.py', extracted / 'tools/paths.py')
            script = 'import paths; print(paths.CORE_ROOT); print(paths.FORGE_ROOT); print(paths.core_path("build/check"))'
            env = dict(os.environ, KARABAS_FORGE_ROOT=str(FORGE), PYTHONDONTWRITEBYTECODE='1')
            proc = subprocess.run([sys.executable, '-c', script], cwd=extracted / 'tools', env=env, text=True, capture_output=True, check=True)
            self.assertEqual(proc.stdout.splitlines(), [str(extracted), str(FORGE), str(extracted / 'build/check')])
            env['KARABAS_FORGE_ROOT'] = str(Path(tmp) / 'missing')
            proc = subprocess.run([sys.executable, '-c', 'import paths'], cwd=extracted / 'tools', env=env, text=True, capture_output=True)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn('Set KARABAS_FORGE_ROOT', proc.stderr)

    def test_cli_help_does_not_depend_on_working_directory(self):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
        for name in ['forge.py', 'bootstrap.py', 'bios_inspect.py', 'gs_audio.py', 'media.py']:
            with self.subTest(tool=name):
                proc = subprocess.run([sys.executable, str(CORE / 'tools' / name), '--help'], cwd=FORGE / 'tmp', env=env, text=True, capture_output=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)

if __name__ == '__main__':
    unittest.main()
