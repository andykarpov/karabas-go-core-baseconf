#!/usr/bin/env python3
"""Verify and bundle all BaseConf FPGA targets with the shared UKNC-compatible RP2040 firmware."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import zipfile

import forge
from paths import CORE_ROOT as ROOT, core_path

BOARDS = {'go': 'kg1', 'mini': 'kg2', 'minig': 'kg3'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_uf2(path):
    data = path.read_bytes()
    require(len(data) > 0 and len(data) % 512 == 0, 'Invalid UF2 length')
    addresses = set()
    for index in range(len(data) // 512):
        block = data[index * 512:(index + 1) * 512]
        first, second, flags, address, size, number, total, family = struct.unpack('<8I', block[:32])
        require((first, second) == (0x0a324655, 0x9e5d5157), 'UF2 magic')
        require(struct.unpack('<I', block[-4:])[0] == 0x0ab16f30, 'UF2 end magic')
        require(flags & 0x2000 and family == 0xe48bff56, 'UF2 must target RP2040')
        require(size == 256 and number == index and total == len(data) // 512, 'UF2 block order/size')
        require(0x10000000 <= address and address + size <= 0x11000000 and address % 256 == 0,
                'UF2 address outside RP2040 firmware flash')
        require(address not in addresses, 'Duplicate UF2 address')
        addresses.add(address)


def controller(board, firmware_root):
    """Reuse the exact controller binaries already supplied for UKNC; do not regress it."""
    ext = BOARDS[board]
    name = f'mc0511-{board}-firmware.uf2'
    path = firmware_root / 'bin' / ext / name
    bundle = json.loads((path.parent / 'manifest.json').read_text())
    require(bundle['board'] == board, 'Firmware board mismatch')
    item = bundle['files'][name]
    require(digest(path) == item['sha256'] and path.stat().st_size == item['bytes'], 'Firmware bundle checksum')
    record_name = 'firmware-completed.json' if board == 'go' else f'firmware-{board}-completed.json'
    record = json.loads((firmware_root / 'build' / record_name).read_text())
    require(record['uf2_sha256'] == digest(path), 'Firmware completion record mismatch')
    source_root = firmware_root / 'build/firmware'
    sources = {str(p.relative_to(source_root)): digest(p) for p in sorted(source_root.rglob('*'))
               if p.is_file() and '.pio' not in p.parts and p.suffix in ('.cpp', '.c', '.h', '.inc', '.ini', '.py')}
    require(sources == record['sources'], 'Controller generated sources changed since compilation')
    verify_uf2(path)
    return path, dict(source_core='mc0511', source_build=bundle['build'], board=board,
                      sha256=digest(path), completion_record_sha256=digest(firmware_root / 'build' / record_name),
                      compatibility='Same controller binary as the UKNC bundle; retains standard BaseConf MCU protocol. This bundle combination has not been separately tested on hardware.')


def release(build_root, firmware_root):
    require(build_root.is_relative_to(ROOT / 'build') and build_root != ROOT / 'build',
            '--build-root must be below this core build/')
    entries = {}
    records = {}
    build = json.loads((ROOT / 'config/core.json').read_text())['build']
    for board, ext in BOARDS.items():
        forge.BOARD, forge.TARGET, forge.EXTENSION = board, 'karabas_' + board, ext
        original = build_root / board
        evidence = json.loads((original / 'ise-completed.json').read_text())
        # Regenerate into a separate directory: old passing reports alone do not
        # establish that today's maintained sources match the routed design.
        forge.OUT = ROOT / 'build/release-audit' / board
        forge.prepare()
        require(digest(forge.OUT / 'manifest.json') == evidence['manifest_sha256'],
                f'{board}: maintained inputs differ from implementation; rerun ISE for this target')
        forge.OUT = original
        forge.package()  # checks routed hashes/timing and independently decodes FPGA, ROMs and all OSD fields
        package = original / f'baseconf.{ext}'
        firmware, firmware_record = controller(board, firmware_root)
        dest = ROOT / 'bin' / ext
        dest.mkdir(parents=True, exist_ok=True)
        files = {}
        for source, name in [(package, package.name), (firmware, f'karabas-{board}-firmware.uf2')]:
            shutil.copyfile(source, dest / name)
            files[name] = dict(bytes=source.stat().st_size, sha256=digest(source))
            entries[f'{ext}/{name}'] = dest / name
        record = dict(board=board, build=build, files=files, fpga=evidence, controller=firmware_record,
                      status='Existing 26102806 FPGA implementation revalidated against current sources; bundled controller pairing awaits hardware testing.',
                      known_issue='Mini/Mini G AY noise remains unresolved; this release does not change audio RTL.')
        record['package_verification'] = json.loads((original / 'package-verified.json').read_text())
        require(record['package_verification']['build'] == build, 'Wrong core build')
        for name in ('bios-result.json', 'bios-reset-result.json', 'video-result.json'):
            path = original / name
            if path.exists():
                proof = json.loads(path.read_text())
                require(proof['manifest_sha256'] == evidence['manifest_sha256'], f'{board}: stale {name}')
                entries[f'validation/{board}/{name}'] = path
        for suffix in (['.twr'] if board == 'go' else ['.twr', '_core.twr']):
            path = original / (forge.TARGET + suffix)
            entries[f'validation/{board}/{path.name}'] = path
        for name in ('ise-completed.json', 'manifest.json', 'package-verified.json', 'core.json'):
            entries[f'validation/{board}/{name}'] = original / name
        (dest / 'manifest.json').write_text(json.dumps(record, indent=2) + '\n')
        entries[f'{ext}/manifest.json'] = dest / 'manifest.json'
        records[board] = record
        print(f'PASS {board}: fresh inputs match ISE; package and RP2040 verified', flush=True)
    # Resource hashes were checked by prepare; inspect the supplied Dune containers too.
    from media import inspect
    media_record = inspect(ROOT / 'res/media/dune')
    for name in ('dune.trd', 'DUNE.DAT'):
        entries[f'SD2/{name}'] = ROOT / 'res/media/dune' / name
    entries['test-media/external.mod'] = ROOT / 'res/media/external.mod'
    readme = ROOT / 'bin/INSTALL.md'
    readme.write_text('# ZX Evolution BaseConf 26102806\n\n'
                      'KG1 / GO, KG2 / Mini, KG3 / Mini G and matching RP2040 firmware.\n\n'
                      'Read [installation and build instructions](docs/builds-and-installation.md).\n'
                      'Use the matching board files; keep your existing boot core.\n'
                      'The UF2 files match the UKNC bundle: no reflash is needed if already installed.\n\n'
                      'Mini/Mini G AY noise remains unresolved. No device was flashed for this bundle.\n'
                      'SHA256SUMS covers all archive files; validation/ contains implementation reports.\n')
    entries['README.md'] = readme
    # Keep documentation paths intact so linked controls/evidence remain usable offline.
    for path in sorted((ROOT / 'docs').rglob('*')):
        if path.is_file() and path.suffix in ('.md', '.json'):
            entries['docs/' + str(path.relative_to(ROOT / 'docs'))] = path
    entries['config/sources.lock.json'] = ROOT / 'config/sources.lock.json'
    summary = ROOT / 'bin/release-manifest.json'
    summary.write_text(json.dumps(dict(build=build, boards=records, media=media_record,
                                      board_transfer_performed=False, ay_noise_fixed=False), indent=2) + '\n')
    entries['release-manifest.json'] = summary
    checksums = ''.join(f'{digest(path)}  {name}\n' for name, path in sorted(entries.items()))
    archive = ROOT / 'bin' / f'baseconf-{build}-all.zip'
    temporary = archive.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for name, path in sorted(entries.items()):
            z.write(path, name)
        # The root README uses core-relative docs links; canonical guide is docs/.
        z.writestr('SHA256SUMS', checksums)
    with zipfile.ZipFile(temporary) as z:
        for line in checksums.splitlines():
            expected, name = line.split('  ', 1)
            require(hashlib.sha256(z.read(name)).hexdigest() == expected, f'Archive checksum: {name}')
    temporary.replace(archive)
    archive.with_suffix('.zip.sha256').write_text(f'{digest(archive)}  {archive.name}\n')
    print(f'Created and verified {archive} ({archive.stat().st_size:,} bytes)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-root', type=core_path, default=ROOT / 'build/reset-26102806',
                        help='Completed build directory with go/, mini/ and minig/ subdirectories')
    parser.add_argument('--firmware-root', type=Path, default=ROOT.parent / 'mc0511',
                        help='UKNC core directory containing the verified shared controller bundles and build records')
    args = parser.parse_args()
    try:
        release(args.build_root.resolve(), args.firmware_root.resolve())
    except (OSError, ValueError, RuntimeError) as exc:
        parser.exit(1, f'ERROR: {exc}\n')

if __name__ == '__main__':
    main()
