"""Resolve core and shared Forge paths without depending on the working directory."""
import os
from pathlib import Path
import sys

CORE_ROOT = Path(__file__).resolve().parents[1]

def find_forge_root():
    configured = os.environ.get('KARABAS_FORGE_ROOT')
    candidates = [Path(configured).expanduser().resolve()] if configured else CORE_ROOT.parents
    for candidate in candidates:
        if (candidate / 'config/forge.json').is_file():
            return candidate
    raise RuntimeError('Shared Forge workspace not found. Set KARABAS_FORGE_ROOT to its root (containing config/forge.json).')

FORGE_ROOT = find_forge_root()
HDL_ROOT = FORGE_ROOT / 'bin/hdl/usr'
# Shared utilities are kept in one place, including after extracting this core.
sys.path.append(str(FORGE_ROOT / 'tools'))

def core_path(value):
    path = Path(value).expanduser()
    return (CORE_ROOT / path).resolve() if not path.is_absolute() else path.resolve()
