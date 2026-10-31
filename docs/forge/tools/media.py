#!/usr/bin/env python3
"""Inspect supplied Dune test media and optionally stage unchanged copies in build/media.
This validates container structure and checksums, not gameplay or FPGA compatibility.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def inspect(directory):
    entries = []
    for name in ('dune.trd', 'DUNE.DAT'):
        path = directory / name
        data = path.read_bytes()
        entries.append({'name': name, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    trd = (directory / 'dune.trd').read_bytes()
    if len(trd) != 655360 or trd[0x8e3] != 0x16 or trd[0x8e7] != 0x10:
        raise ValueError('Expected a 640 KB double-sided 80-track TR-DOS image')
    files, used = [], set()
    for offset in range(0, 2048, 16):
        entry = trd[offset:offset+16]
        if entry[0] in (0, 1):
            continue
        start = entry[15] * 16 + entry[14]
        sectors = entry[13]
        length = int.from_bytes(entry[11:13], 'little')
        if entry[14] >= 16 or start < 16 or start+sectors > len(trd)//256 or length > sectors*256:
            raise ValueError(f'Invalid TR-DOS file extent at directory offset {offset}')
        allocated = set(range(start, start+sectors))
        if used & allocated:
            raise ValueError('Overlapping TR-DOS file extents')
        used |= allocated
        files.append({'name': entry[:8].decode('ascii').rstrip(), 'type': chr(entry[8]),
                      'start_sector': start, 'sectors': sectors, 'length': length})
    if len(files) != trd[0x8e4]:
        raise ValueError('TR-DOS catalogue count mismatch')
    spg = (directory / 'DUNE.DAT').read_bytes()
    if spg[32:44] != b'SpectrumProg':
        raise ValueError('DUNE.DAT lacks the SpectrumProg container signature')
    return {'media': entries, 'trd_files': files, 'dat_container': 'SpectrumProg',
            'gameplay_tested': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default='res/media/dune', help='Input directory inside the project')
    parser.add_argument('--stage', action='store_true', help='Copy validated files to build/media without modifying originals')
    args = parser.parse_args()
    try:
        source = (ROOT / args.source).resolve()
        if not source.is_relative_to(ROOT):
            raise ValueError('Source must be inside the project')
        report = inspect(source)
        if args.stage:
            dest = ROOT / 'build/media'
            dest.mkdir(parents=True, exist_ok=True)
            for entry in report['media']:
                shutil.copyfile(source / entry['name'], dest / entry['name'])
            (dest / 'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps(report, indent=2))
    except (OSError, ValueError) as exc:
        parser.exit(1, f'ERROR: {exc}\n')

if __name__ == '__main__':
    main()
