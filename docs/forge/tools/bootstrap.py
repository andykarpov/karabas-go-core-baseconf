#!/usr/bin/env python3
"""Bootstrap this core's pinned dependencies using the shared Forge tools."""
import runpy
import sys
from paths import CORE_ROOT, FORGE_ROOT

if __name__ == '__main__':
    sys.argv[1:1] = ['--project', str(CORE_ROOT)]
    runpy.run_path(str(FORGE_ROOT / 'tools/bootstrap.py'), run_name='__main__')
